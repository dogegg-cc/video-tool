//
//  ConvertViewModel.swift
//  VideoTool
//

import Combine
import SwiftUI

@MainActor
class ConvertViewModel: ObservableObject {
    @Published var tasks: [ConvertTask] = []
    @Published var outputDirectory: URL = {
        let fm = FileManager.default

        // 1. 优先尝试从 UserDefaults 中恢复保存的 Security-Scoped Bookmark (安全范围书签)
        if let bookmarkData = UserDefaults.standard.data(forKey: "sandbox_directory_bookmark") {
            var isStale = false
            let restoredURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if let restoredURL {
                DebugLog.info("Successfully restored output directory bookmark: \(restoredURL.path)")

                // 如果凭据已陈旧（stale），重新生成以保鲜
                if isStale {
                    let newBookmark = try? restoredURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    if let newBookmark {
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
        return fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
    }() {
        didSet {
            // 当输出目录变更时，自动将其转化为 Security-Scoped Bookmark 持久化保存至 UserDefaults
            saveBookmark(for: outputDirectory)
        }
    }

    @Published var globalFormat: VideoFormat = .mp4 {
        didSet {
            updatePendingTasks()
        }
    }

    @Published var globalResolution: VideoResolution = .original {
        didSet {
            updatePendingTasks()
        }
    }

    @Published var globalHardwareAccel: Bool = true {
        didSet {
            updatePendingTasks()
        }
    }

    private func updatePendingTasks() {
        for i in 0 ..< tasks.count {
            if case .pending = tasks[i].status {
                tasks[i].targetFormat = globalFormat
                tasks[i].resolution = globalResolution
                tasks[i].useHardwareAcceleration = globalHardwareAccel
            }
        }
    }

    @Published var logs: String = ""
    @Published var isConverting: Bool = false
    @Published var currentTaskIndex: Int = 0

    private var logBuffer = ""
    private var isLogUpdateScheduled = false

    // 添加任务到队列
    func addVideo(url: URL, bookmarkData: Data? = nil) {
        var resolvedBookmark = bookmarkData
        if resolvedBookmark == nil {
            let isScoped = url.startAccessingSecurityScopedResource()
            resolvedBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 使用安全访问机制获取视频时长，传入安全范围书签以确保时长解析成功
        let duration = VideoConverterEngine.shared.getVideoDuration(at: url, bookmarkData: resolvedBookmark)

        let task = ConvertTask(
            sourceURL: url,
            targetFormat: globalFormat,
            resolution: globalResolution,
            useHardwareAcceleration: globalHardwareAccel,
            duration: duration,
            securityBookmark: resolvedBookmark
        )
        tasks.append(task)
    }

    // 检查并一次性请求输出目录的写入授权（只询问一次保底机制）
    func checkAndRequestOutputDirectoryPermission(completion: @escaping @MainActor (Bool) -> Void) {
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
            let openPanel = NSOpenPanel()
            openPanel.title = "请选择并授权一个用于保存视频的文件夹"
            openPanel.message = "受 macOS 系统沙盒安全限制，请选择并授权一个文件夹。后续转码队列中的所有视频都会直接、静默地自动保存至此文件夹，不再重复询问。"
            openPanel.prompt = "授权此文件夹并开始"
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false

            if openPanel.runModal() == .OK, let authorizedURL = openPanel.url {
                outputDirectory = authorizedURL
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    // 开始队列转换
    func startQueue() {
        guard !tasks.isEmpty else { return }

        // 检查并一次性请求输出目录权限，只在开头询问一次！
        checkAndRequestOutputDirectoryPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                logs += "\n❌ [授权中止] 未能获得保存文件夹的授权，转码中止。\n"
                return
            }

            // 重置所有非 completed 状态的任务为 pending 以便重跑
            for i in 0 ..< tasks.count {
                switch tasks[i].status {
                case .failed, .cancelled:
                    tasks[i].status = .pending
                default:
                    break
                }
            }

            isConverting = true
            logs += "=== 开始转换队列 ===\n"
            processNext()
        }
    }

    private func processNext() {
        // 查找第一个 pending 状态的任务
        guard let index = tasks.firstIndex(where: {
            if case .pending = $0.status { return true }
            return false
        }) else {
            // 所有任务完成
            isConverting = false
            logs += "\n=== 所有任务转换完成！ ===\n"
            return
        }

        currentTaskIndex = index
        let task = tasks[index]

        tasks[index].status = .converting(progress: 0.0, speed: "0.0x", eta: "计算中...")
        logs += "\n[开始转换] \(task.fileName) -> \(task.targetFormat.rawValue)\n"

        VideoConverterEngine.shared.convert(
            task: task,
            outputDir: outputDirectory,
            onProgress: { [weak self] progress, speed in
                guard let self else { return }
                Task { @MainActor in
                    self.tasks[index].status = .converting(progress: progress, speed: speed, eta: "")
                }
            },
            onLog: { [weak self] logLine in
                self?.sendLogLine(logLine)
            },
            onCompletion: { [weak self] success, outputPath, tempURL in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleConversionCompletion(
                        index: index,
                        task: task,
                        success: success,
                        outputPath: outputPath,
                        tempURL: tempURL
                    )
                }
            }
        )
    }

    private func handleConversionCompletion(
        index: Int,
        task: ConvertTask,
        success: Bool,
        outputPath: String?,
        tempURL: URL?
    ) async {
        if success {
            tasks[index].status = .completed
            logs += "\n[转换成功] 输出路径: \(outputPath ?? "")\n"
            processNext()
            return
        }

        // 智能重试：仅当日志明确表示不支持硬件加速编码器时触发回退重试
        let logLower = logs.lowercased()
        let isHardwareIssue = logLower.contains("unknown encoder") ||
            logLower.contains("encoder not found") ||
            logLower.contains("unrecognized option") ||
            logLower.contains("cannot create compression session") ||
            logLower.contains("prores_videotoolbox")

        if task.useHardwareAcceleration, isHardwareIssue {
            logs += "\n⚠️ [系统检测] 硬件加速编解码器创建会话失败（不支持或分辨率奇葩）。\n"
            logs += "🔄 [自动回退] 正在切换至 CPU 兼容编码器重新尝试转换...\n"
            tasks[index].useHardwareAcceleration = false
            tasks[index].status = .pending

            // 延迟 100ms 调度，防止在同一 RunLoop 中触发线程竞争
            try? await Task.sleep(nanoseconds: 100_000_000)
            processNext()
        } else if let tempURL {
            logs += "\n🔒 [沙盒安全] 写入输出目录遭遇权限拦截，正在弹出“另存为”面板引导您手动选择保存位置...\n"

            let sourceName = task.sourceURL.deletingPathExtension().lastPathComponent
            let targetExt = task.targetFormat.extensionName
            let defaultName = "\(sourceName)_converted.\(targetExt)"

            presentSavePanel(for: tempURL, defaultName: defaultName) { saved, savedPath in
                Task { @MainActor in
                    if saved {
                        self.tasks[index].status = .completed
                        self.logs += "\n[手动保存成功] 文件存入: \(savedPath ?? "")\n"
                    } else {
                        self.tasks[index].status = .failed(error: "用户取消或保存失败")
                        self.logs += "\n[保存中止] 未能写入文件。\n"
                    }

                    // 延迟 50ms 继续调度下一个任务
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    self.processNext()
                }
            }
        } else {
            let errorMsg = outputPath ?? "原因未知，请检查控制台日志"
            tasks[index].status = .failed(error: errorMsg)
            logs += "\n[转换失败] 原因: \(errorMsg)\n"

            // 同样为后续任务的继续提供 50ms 间隔缓冲
            try? await Task.sleep(nanoseconds: 50_000_000)
            processNext()
        }
    }

    // NSSavePanel 引导保存保底
    func presentSavePanel(for tempURL: URL, defaultName: String, completion: @escaping @MainActor (Bool, String?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "选择保存转换后视频的位置"
        savePanel.nameFieldStringValue = defaultName
        savePanel.isExtensionHidden = false
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            Task { @MainActor in
                if response == .OK, let targetURL = savePanel.url {
                    do {
                        if FileManager.default.fileExists(atPath: targetURL.path) {
                            try? FileManager.default.removeItem(at: targetURL)
                        }
                        try FileManager.default.copyItem(at: tempURL, to: targetURL)
                        try? FileManager.default.removeItem(at: tempURL)
                        completion(true, targetURL.path)
                    } catch {
                        completion(false, "写入失败: \(error.localizedDescription)")
                    }
                } else {
                    try? FileManager.default.removeItem(at: tempURL)
                    completion(false, "用户取消保存")
                }
            }
        }
    }
}

// MARK: - 辅助授权与队列操作扩展

extension ConvertViewModel {
    // 生成并持久化保存 Security-Scoped Bookmark
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "sandbox_directory_bookmark")
            DebugLog.info("Successfully saved security scoped bookmark for URL: \(url.path)")
        } catch {
            DebugLog.error("Failed to create security scoped bookmark: \(error.localizedDescription)")
        }
    }

    func cancelAll() {
        VideoConverterEngine.shared.cancelCurrentConversion()
        for i in 0 ..< tasks.count {
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

    func clearLogs() {
        logs = ""
        logBuffer = ""
    }

    // MARK: - 极简高性能日志节流系统 (High-Performance Log Throttling)

    func sendLogLine(_ line: String) {
        // 在后台或主线程调用，安全地追加到临时缓冲区，以 150ms 频率节流刷新 UI，保证 60 FPS 的流畅度
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            logBuffer += line

            if !isLogUpdateScheduled {
                isLogUpdateScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.flushLogBuffer()
                }
            }
        }
    }

    func flushLogBuffer() {
        isLogUpdateScheduled = false
        guard !logBuffer.isEmpty else { return }

        var current = logs + logBuffer
        logBuffer = ""

        // 限制最大展示长度，防 SwiftUI Text 产生排版性能瓶颈
        let maxLen = 40000
        if current.count > maxLen {
            let offset = current.count - maxLen
            let index = current.index(current.startIndex, offsetBy: offset)
            current = "..." + String(current[index...])
        }
        logs = current
    }
}
