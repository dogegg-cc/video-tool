//
//  VideoConverterEngine.swift
//  VideoTool
//

import ffmpegkit
import Foundation

class VideoConverterEngine {
    static let shared = VideoConverterEngine()
    private var activeSessionId: Int?

    /// 获取视频时长（秒）
    func getVideoDuration(at url: URL) -> Double {
        guard url.startAccessingSecurityScopedResource() else {
            DebugLog.error("Failed to start accessing security scoped resource for duration")
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

        // 确保输出目录有安全范围权限凭证 (在 C 回调线程执行前保持 active 状态)
        let isOutputDirScoped = outputDir.startAccessingSecurityScopedResource()

        defer {
            task.sourceURL.stopAccessingSecurityScopedResource()
        }

        // 2. 构造临时输出文件名与路径
        let (tempTargetURL, finalTargetURL) = preparePaths(task: task, outputDir: outputDir)

        // 获取视频总时长，用于计算进度
        let duration = getVideoDuration(at: task.sourceURL)
        let totalDurationMs = duration * 1000.0

        // 3. 构建 FFmpeg 命令行指令
        let arguments = buildFFmpegArguments(task: task, tempTargetURL: tempTargetURL)

        // 4. 异步执行转换
        DebugLog.info("Executing FFmpeg command: \(arguments)")
        let session = FFmpegKit.executeAsync(
            arguments,
            withCompleteCallback: { [weak self] session in
                if isOutputDirScoped {
                    _ = finalTargetURL.startAccessingSecurityScopedResource()
                }
                defer {
                    if isOutputDirScoped {
                        finalTargetURL.stopAccessingSecurityScopedResource()
                        outputDir.stopAccessingSecurityScopedResource()
                    }
                }

                guard let self else { return }
                handleSessionComplete(
                    session: session,
                    tempTargetURL: tempTargetURL,
                    finalTargetURL: finalTargetURL,
                    onCompletion: onCompletion
                )
            },
            withLogCallback: { log in
                guard let log else { return }
                onLog(log.getMessage())
            },
            withStatisticsCallback: { statistics in
                guard let statistics else { return }
                let timeMs = Double(statistics.getTime())
                if totalDurationMs > 0 {
                    let percentage = min(max(timeMs / totalDurationMs, 0.0), 1.0)
                    let speed = String(format: "%.1fx", statistics.getSpeed())
                    onProgress(percentage, speed)
                }
            }
        )

        recordSessionId(from: session)
    }

    private func preparePaths(task: ConvertTask, outputDir: URL) -> (tempTargetURL: URL, finalTargetURL: URL) {
        let baseName = task.sourceURL.deletingPathExtension().lastPathComponent
        let targetFileName = "\(baseName)_converted.\(task.targetFormat.extensionName)"

        let tempDir = FileManager.default.temporaryDirectory
        let tempUUID = UUID().uuidString
        let tempTargetURL = tempDir.appendingPathComponent("\(tempUUID).\(task.targetFormat.extensionName)")
        let finalTargetURL = outputDir.appendingPathComponent(targetFileName)

        if FileManager.default.fileExists(atPath: finalTargetURL.path) {
            try? FileManager.default.removeItem(at: finalTargetURL)
        }

        return (tempTargetURL, finalTargetURL)
    }

    private func buildFFmpegArguments(task: ConvertTask, tempTargetURL: URL) -> String {
        var arguments = "-y -i \"\(task.sourceURL.path)\""
        arguments += getEncoderArguments(for: task)

        if task.targetFormat != .gif, let scaleArg = task.resolution.scaleArgument {
            arguments += scaleArg
        }

        arguments += " \"\(tempTargetURL.path)\""
        return arguments
    }

    private func recordSessionId(from session: Session?) {
        guard let session = session as? NSObject else { return }
        if let dynId = session.value(forKey: "sessionId") as? Int {
            activeSessionId = dynId
        } else if let dynId64 = session.value(forKey: "sessionId") as? Int64 {
            activeSessionId = Int(dynId64)
        }
    }

    private func handleSessionComplete(
        session: Session?,
        tempTargetURL: URL,
        finalTargetURL: URL,
        onCompletion: @escaping (Bool, String?, URL?) -> Void
    ) {
        guard let session else {
            onCompletion(false, "无法创建 FFmpeg 会话", nil)
            return
        }

        let returnCode = session.getReturnCode()
        activeSessionId = nil

        if ReturnCode.isSuccess(returnCode) {
            do {
                if FileManager.default.fileExists(atPath: finalTargetURL.path) {
                    try? FileManager.default.removeItem(at: finalTargetURL)
                }

                do {
                    // 优先尝试高效剪切
                    try FileManager.default.moveItem(at: tempTargetURL, to: finalTargetURL)
                } catch {
                    DebugLog.error("moveItem failed, fallback to copyItem: \(error.localizedDescription)")
                    // 剪切失败，使用复制保底机制（彻底兼容跨分区/沙盒映射挂载限制）
                    try FileManager.default.copyItem(at: tempTargetURL, to: finalTargetURL)
                    // 复制成功后删除沙盒内的临时文件
                    try? FileManager.default.removeItem(at: tempTargetURL)
                }

                DebugLog.info("Successfully saved file to target: \(finalTargetURL.path)")
                onCompletion(true, finalTargetURL.path, nil)
            } catch {
                DebugLog.error("Failed to save converted file: \(error.localizedDescription)")
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

    // MARK: - 编码参数路由分支 (Single Responsibility & Low Complexity)

    private func getEncoderArguments(for task: ConvertTask) -> String {
        switch task.targetFormat {
        case .mp4:
            if task.useHardwareAcceleration {
                return " -c:v h264_videotoolbox -b:v 5000k -c:a aac -b:a 192k"
            }
            return " -c:v libx264 -c:a aac -b:a 192k"

        case .hevc:
            if task.useHardwareAcceleration {
                return " -c:v hevc_videotoolbox -b:v 4000k -c:a aac -b:a 192k"
            }
            return " -c:v libx265 -c:a aac -b:a 192k"

        case .mkv:
            return " -c:v libx264 -c:a aac"

        case .mov:
            return " -c:v prores_videotoolbox -profile:v 0 -c:a pcm_s16le"

        case .gif:
            return " -vf \"fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\""

        case .mp3:
            return " -vn -c:a libmp3lame -q:a 2"
        }
    }
}
