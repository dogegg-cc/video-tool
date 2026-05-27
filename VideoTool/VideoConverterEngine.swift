//
//  VideoConverterEngine.swift
//  VideoTool
//

import Foundation
import ffmpegkit

class VideoConverterEngine {
    static let shared = VideoConverterEngine()
    private var activeSessionId: Int?
    
    /// 获取视频时长（秒）
    func getVideoDuration(at url: URL) -> Double {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to start accessing security scoped resource for duration")
            return 0.0
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let mediaInformationSession = FFprobeKit.getMediaInformation(url.path)
        if let info = mediaInformationSession?.getMediaInformation() {
            if let durationStr = info.getDuration(), let duration = Double(durationStr) {
                return duration
            }
        }
        return 0.0
    }
    
    /// 执行格式转换
    func convert(
        task: ConvertTask,
        outputDir: URL,
        onProgress: @escaping (Double, String) -> Void, // (进度0~1, 速度)
        onLog: @escaping (String) -> Void,
        onCompletion: @escaping (Bool, String?, URL?) -> Void
    ) {
        // 1. 获取安全访问权限（沙盒兼容）
        guard task.sourceURL.startAccessingSecurityScopedResource() else {
            onCompletion(false, "无法读取源文件权限", nil)
            return
        }
        
        // 确保输出目录有安全范围权限凭证
        _ = outputDir.startAccessingSecurityScopedResource()
        
        defer {
            task.sourceURL.stopAccessingSecurityScopedResource()
            outputDir.stopAccessingSecurityScopedResource()
        }
        
        // 2. 构造临时输出文件名与真正的输出路径
        let baseName = task.sourceURL.deletingPathExtension().lastPathComponent
        let targetFileName = "\(baseName)_converted.\(task.targetFormat.extensionName)"
        
        // 核心突破：FFmpeg 跨平台 C 语言底层线程不共享 macOS 安全访问凭证。
        // 我们在系统分配的应用沙盒独占临时目录下（具有绝对读写权限）让 FFmpeg 进行写入，百分之百避免沙盒拦截。
        let tempDir = FileManager.default.temporaryDirectory
        let tempUUID = UUID().uuidString
        let tempTargetURL = tempDir.appendingPathComponent("\(tempUUID).\(task.targetFormat.extensionName)")
        
        // 外部指定的最终归档路径
        let finalTargetURL = outputDir.appendingPathComponent(targetFileName)
        
        // 提前删除最终路径下的同名残留，防移动冲突
        if FileManager.default.fileExists(atPath: finalTargetURL.path) {
            try? FileManager.default.removeItem(at: finalTargetURL)
        }
        
        // 获取视频总时长，用于计算进度
        let duration = getVideoDuration(at: task.sourceURL)
        let totalDurationMs = duration * 1000.0
        
        // 3. 构建 FFmpeg 命令行指令，输出指向具有读写特权的 tempTargetURL
        var arguments = "-y -i \"\(task.sourceURL.path)\""
        
        // 编码器与硬件加速设置
        switch task.targetFormat {
        case .mp4:
            if task.useHardwareAcceleration {
                arguments += " -c:v h264_videotoolbox -b:v 5000k"
            } else {
                arguments += " -c:v libx264"
            }
            arguments += " -c:a aac -b:a 192k"
            
        case .hevc:
            if task.useHardwareAcceleration {
                arguments += " -c:v hevc_videotoolbox -b:v 4000k"
            } else {
                arguments += " -c:v libx265"
            }
            arguments += " -c:a aac -b:a 192k"
            
        case .mkv:
            arguments += " -c:v libx264 -c:a aac"
            
        case .mov:
            // ProRes 编码适合剪辑
            arguments += " -c:v prores_videotoolbox -profile:v 0 -c:a pcm_s16le"
            
        case .gif:
            arguments += " -vf \"fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\""
            
        case .mp3:
            arguments += " -vn -c:a libmp3lame -q:a 2"
        }
        
        // 分辨率裁剪参数（基于强类型枚举映射）
        if task.targetFormat != .gif, let scaleArg = task.resolution.scaleArgument {
            arguments += scaleArg
        }
        
        arguments += " \"\(tempTargetURL.path)\""
        
        // 4. 异步执行转换
        print("Executing FFmpeg command: \(arguments)")
        let session = FFmpegKit.executeAsync(
            arguments,
            withCompleteCallback: { session in
                guard let session = session else {
                    onCompletion(false, "无法创建 FFmpeg 会话", nil)
                    return
                }
                
                let returnCode = session.getReturnCode()
                self.activeSessionId = nil
                
                if ReturnCode.isSuccess(returnCode) {
                    // 转码在沙盒临时区大功告成！现在在主进程 Swift 层（拥有完整外部 Scoped 授权）将文件剪切至最终目录
                    do {
                        let isScoped = finalTargetURL.startAccessingSecurityScopedResource()
                        defer {
                            if isScoped {
                                finalTargetURL.stopAccessingSecurityScopedResource()
                            }
                        }
                        
                        if FileManager.default.fileExists(atPath: finalTargetURL.path) {
                            try? FileManager.default.removeItem(at: finalTargetURL)
                        }
                        
                        do {
                            // 优先尝试高效剪切
                            try FileManager.default.moveItem(at: tempTargetURL, to: finalTargetURL)
                        } catch {
                            print("moveItem failed, fallback to copyItem: \(error.localizedDescription)")
                            // 剪切失败，使用复制保底机制（彻底兼容跨分区/沙盒映射挂载限制）
                            try FileManager.default.copyItem(at: tempTargetURL, to: finalTargetURL)
                            // 复制成功后删除沙盒内的临时文件
                            try? FileManager.default.removeItem(at: tempTargetURL)
                        }
                        
                        print("Successfully saved file to target: \(finalTargetURL.path)")
                        onCompletion(true, finalTargetURL.path, nil)
                    } catch {
                        print("Failed to save converted file: \(error.localizedDescription)")
                        // 关键保留：转码成功但移动/写入目标权限失败，不清理 tempTargetURL，并传回给 UI 层做 NSSavePanel 保底
                        onCompletion(false, "保存转换文件至输出目录失败: \(error.localizedDescription)", tempTargetURL)
                    }
                } else {
                    // 转码彻底失败，清理垃圾临时文件
                    try? FileManager.default.removeItem(at: tempTargetURL)
                    
                    if ReturnCode.isCancel(returnCode) {
                        onCompletion(false, "转换已取消", nil)
                    } else {
                        let failOutput = session.getFailStackTrace() ?? "未知错误"
                        onCompletion(false, failOutput, nil)
                    }
                }
            },
            withLogCallback: { log in
                guard let log = log else { return }
                onLog(log.getMessage())
            },
            withStatisticsCallback: { statistics in
                guard let statistics = statistics else { return }
                let timeMs = Double(statistics.getTime())
                if totalDurationMs > 0 {
                    let percentage = min(max(timeMs / totalDurationMs, 0.0), 1.0)
                    let speed = String(format: "%.1fx", statistics.getSpeed())
                    onProgress(percentage, speed)
                }
            }
        )
        
        if let session = session {
            if let dynId = session.value(forKey: "sessionId") as? Int {
                self.activeSessionId = dynId
            } else if let dynId64 = session.value(forKey: "sessionId") as? Int64 {
                self.activeSessionId = Int(dynId64)
            }
        }
    }
    
    /// 取消当前转换
    func cancelCurrentConversion() {
        if let sessionId = activeSessionId {
            FFmpegKit.cancel(sessionId)
            activeSessionId = nil
        } else {
            FFmpegKit.cancel()
        }
    }
}
