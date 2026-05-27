//
//  ConvertViewModel.swift
//  VideoTool
//

import SwiftUI
import Combine

class ConvertViewModel: ObservableObject {
    @Published var tasks: [ConvertTask] = []
    @Published var outputDirectory: URL = {
        let fm = FileManager.default
        
        // 1. 优先尝试从 UserDefaults 中恢复保存的 Security-Scoped Bookmark (安全范围书签)
        if let bookmarkData = UserDefaults.standard.data(forKey: "sandbox_directory_bookmark") {
            var isStale = false
            if let restoredURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                print("Successfully restored output directory bookmark: \(restoredURL.path)")
                
                // 如果凭据已陈旧（stale），重新生成以保鲜
                if isStale {
                    if let newBookmark = try? restoredURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(newBookmark, forKey: "sandbox_directory_bookmark")
                    }
                }
                return restoredURL
            }
        }
        
        // 2. 书签不存在或失效时，使用应用专属的沙盒特权 Downloads 目录作为保底
        if let containerDownloads = try? fm.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return containerDownloads
        }
        return fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    }() {
        didSet {
            // 当输出目录变更时，自动将其转化为 Security-Scoped Bookmark 持久化保存至 UserDefaults
            saveBookmark(for: outputDirectory)
        }
    }
    
    @Published var globalFormat: VideoFormat = .mp4
    @Published var globalResolution: VideoResolution = .original
    @Published var globalHardwareAccel: Bool = true
    
    @Published var logs: String = ""
    @Published var isConverting: Bool = false
    @Published var currentTaskIndex: Int = 0
    
    // 生成并持久化保存 Security-Scoped Bookmark
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "sandbox_directory_bookmark")
            print("Successfully saved security scoped bookmark for URL: \(url.path)")
        } catch {
            print("Failed to create security scoped bookmark: \(error.localizedDescription)")
        }
    }
    
    // 添加任务到队列
    func addVideo(url: URL) {
        // 使用安全访问机制获取视频时长
        let duration = VideoConverterEngine.shared.getVideoDuration(at: url)
        
        let task = ConvertTask(
            sourceURL: url,
            targetFormat: globalFormat,
            resolution: globalResolution,
            useHardwareAcceleration: globalHardwareAccel,
            duration: duration
        )
        tasks.append(task)
    }
    
    // 检查并一次性请求输出目录的写入授权（只询问一次保底机制）
    func checkAndRequestOutputDirectoryPermission(completion: @escaping (Bool) -> Void) {
        let fm = FileManager.default
        let testFileURL = outputDirectory.appendingPathComponent(".sandbox_write_test")
        
        let isScoped = outputDirectory.startAccessingSecurityScopedResource()
        do {
            // 尝试在当前保存目录写入测试文件以验证真实沙盒写入权限
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            try? fm.removeItem(at: testFileURL)
            if isScoped {
                outputDirectory.stopAccessingSecurityScopedResource()
            }
            completion(true)
        } catch {
            if isScoped {
                outputDirectory.stopAccessingSecurityScopedResource()
            }
            
            // 无权写入，在转码开始前，主线程弹窗【只引导询问一次】
            DispatchQueue.main.async {
                let openPanel = NSOpenPanel()
                openPanel.title = "请选择并授权一个用于保存视频的文件夹"
                openPanel.message = "受 macOS 系统沙盒安全限制，请选择并授权一个文件夹。后续转码队列中的所有视频都会直接、静默地自动保存至此文件夹，不再重复询问。"
                openPanel.prompt = "授权此文件夹并开始"
                openPanel.canChooseDirectories = true
                openPanel.canChooseFiles = false
                openPanel.allowsMultipleSelection = false
                
                if openPanel.runModal() == .OK, let authorizedURL = openPanel.url {
                    self.outputDirectory = authorizedURL
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    // 开始队列转换
    func startQueue() {
        guard !tasks.isEmpty else { return }
        
        // 核心修复：检查并一次性请求输出目录权限，只在开头询问一次！
        checkAndRequestOutputDirectoryPermission { granted in
            guard granted else {
                DispatchQueue.main.async {
                    self.logs += "\n❌ [授权中止] 未能获得保存文件夹的授权，转码中止。\n"
                }
                return
            }
            
            DispatchQueue.main.async {
                // 重置所有非 completed 状态的任务为 pending 以便重跑
                for i in 0..<self.tasks.count {
                    switch self.tasks[i].status {
                    case .failed, .cancelled:
                        self.tasks[i].status = .pending
                    default:
                        break
                    }
                }
                
                self.isConverting = true
                self.logs += "=== 开始转换队列 ===\n"
                self.processNext()
            }
        }
    }
    
    private func processNext() {
        // 查找第一个 pending 状态的任务
        guard let index = tasks.firstIndex(where: {
            if case .pending = $0.status { return true }
            return false
        }) else {
            // 所有任务完成
            DispatchQueue.main.async {
                self.isConverting = false
                self.logs += "\n=== 所有任务转换完成！ ===\n"
            }
            return
        }
        
        currentTaskIndex = index
        let task = tasks[index]
        
        DispatchQueue.main.async {
            self.tasks[index].status = .converting(progress: 0.0, speed: "0.0x", eta: "计算中...")
            self.logs += "\n[开始转换] \(task.fileName) -> \(task.targetFormat.rawValue)\n"
        }
        
        VideoConverterEngine.shared.convert(
            task: task,
            outputDir: outputDirectory,
            onProgress: { progress, speed in
                DispatchQueue.main.async {
                    self.tasks[index].status = .converting(progress: progress, speed: speed, eta: "")
                }
            },
            onLog: { logLine in
                DispatchQueue.main.async {
                    self.logs += logLine
                }
            },
            onCompletion: { success, outputPath, tempURL in
                DispatchQueue.main.async {
                    if success {
                        self.tasks[index].status = .completed
                        self.logs += "\n[转换成功] 输出路径: \(outputPath ?? "")\n"
                        self.processNext()
                    } else {
                        // 智能重试：仅当日志明确表示不支持硬件加速编码器时触发回退重试
                        let logLower = self.logs.lowercased()
                        if task.useHardwareAcceleration && (logLower.contains("unknown encoder") || logLower.contains("encoder not found") || logLower.contains("unrecognized option")) {
                            self.logs += "\n⚠️ [系统检测] 当前 ffmpegkit 库不支持 VideoToolbox 硬件加速编码器。\n🔄 [自动回退] 正在切换至 CPU 兼容编码器（libx264/libx265）重新尝试转换...\n"
                             // 关闭此任务的硬件加速选项并重置状态为 pending
                            self.tasks[index].useHardwareAcceleration = false
                            self.tasks[index].status = .pending
                            
                            // 关键修复：延迟 100ms 调度，防止在同一 RunLoop 中触发线程竞争和 UI 锁死
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.processNext()
                            }
                        } else if let tempURL = tempURL {
                            // 核心升级：如果转码完成了但因为沙盒外部目录权限写入失败，弹窗引导用户保存文件！
                            self.logs += "\n🔒 [沙盒安全] 写入输出目录遭遇权限拦截，正在弹出“另存为”面板引导您手动选择保存位置...\n"
                            
                            let defaultName = task.sourceURL.deletingPathExtension().lastPathComponent + "_converted.\(task.targetFormat.extensionName)"
                            
                            self.presentSavePanel(for: tempURL, defaultName: defaultName) { saved, savedPath in
                                DispatchQueue.main.async {
                                    if saved {
                                        self.tasks[index].status = .completed
                                        self.logs += "\n[手动保存成功] 文件存入: \(savedPath ?? "")\n"
                                    } else {
                                        self.tasks[index].status = .failed(error: "用户取消或保存失败")
                                        self.logs += "\n[保存中止] 未能写入文件。\n"
                                    }
                                    
                                    // 保存结束（成功/失败）后，继续执行下一个队列任务
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        self.processNext()
                                    }
                                }
                            }
                        } else {
                            self.tasks[index].status = .failed(error: "转换失败")
                            self.logs += "\n[转换失败]\n"
                            
                            // 同样为后续任务的继续提供 50ms 间隔缓冲
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.processNext()
                            }
                        }
                    }
                }
            }
        )
    }
    
    // NSSavePanel 引导保存保底
    private func presentSavePanel(for tempURL: URL, defaultName: String, completion: @escaping (Bool, String?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "选择保存转换后视频的位置"
        savePanel.nameFieldStringValue = defaultName
        savePanel.isExtensionHidden = false
        savePanel.canCreateDirectories = true
        
        // 渲染主线程模态弹框
        savePanel.begin { response in
            if response == .OK, let targetURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try? FileManager.default.removeItem(at: targetURL)
                    }
                    // 拷贝临时区文件到用户指定的位置
                    try FileManager.default.copyItem(at: tempURL, to: targetURL)
                    try? FileManager.default.removeItem(at: tempURL) // 彻底清理沙盒缓存
                    completion(true, targetURL.path)
                } catch {
                    completion(false, "写入失败: \(error.localizedDescription)")
                }
            } else {
                // 用户按了取消，直接清理
                try? FileManager.default.removeItem(at: tempURL)
                completion(false, "用户取消保存")
            }
        }
    }
    
    func cancelAll() {
        VideoConverterEngine.shared.cancelCurrentConversion()
        for i in 0..<tasks.count {
            if case .converting = tasks[i].status {
                tasks[i].status = .cancelled
            }
        }
        isConverting = false
        logs += "\n[用户取消] 转换队列已中止。\n"
    }
    
    func clearCompleted() {
        tasks.removeAll { task in
            if case .completed = task.status { return true }
            if case .cancelled = task.status { return true }
            return false
        }
    }
    
    func removeTask(at index: Int) {
        tasks.remove(at: index)
    }
}
