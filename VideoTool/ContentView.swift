//
//  ContentView.swift
//  VideoTool
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConvertViewModel()
    @State private var isDraggingOver = false
    @State private var showLogs = false
    @State private var consoleHeight: CGFloat = 150
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. 左侧全局控制与预设面板
            SettingsSidebar(viewModel: viewModel)
            
            // 右侧主工作区
            VStack(spacing: 0) {
                // 2. 顶部批处理工具栏
                TopControlBar(viewModel: viewModel)
                
                // 3. 拖拽核心容器区
                ZStack {
                    Color.black.opacity(0.05)
                        .ignoresSafeArea()
                    
                    if viewModel.tasks.isEmpty {
                        // 4. 空状态下的文件拖拽区域
                        DragDropDropzone(isDraggingOver: isDraggingOver, onSelectFiles: selectFiles)
                    } else {
                        // 5. 转码任务卡片列表
                        TaskListView(viewModel: viewModel)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    handleDrop(providers: providers)
                }
                
                // 6. 底部极客控制台
                GeekConsoleView(logs: viewModel.logs, showLogs: $showLogs, consoleHeight: $consoleHeight)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
    }
    
    // MARK: - 文件拖拽与选择交互
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            viewModel.addVideo(url: url)
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func selectFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            for url in openPanel.urls {
                viewModel.addVideo(url: url)
            }
        }
    }
}

// MARK: - 1. 左侧配置面板 (Single Responsibility)

struct SettingsSidebar: View {
    @ObservedObject var viewModel: ConvertViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题区
            HStack(spacing: 8) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("视频格式转换")
                    .font(.system(size: 18, weight: .bold))
                    .fontDesign(.rounded)
            }
            .padding(.top, 10)
            
            Divider()
            
            // 参数配置预设区
            VStack(alignment: .leading, spacing: 15) {
                Text("全局转换预设")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                // 目标格式选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("目标格式")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.globalFormat) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                // 目标分辨率选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("目标分辨率")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.globalResolution) {
                        ForEach(VideoResolution.allCases) { resolution in
                            Text(resolution.label).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                // 硬件加速切换
                Toggle(isOn: $viewModel.globalHardwareAccel) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用苹果硬件加速")
                            .font(.system(size: 12, weight: .medium))
                        Text("VideoToolbox 加速")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            
            Spacer()
            
            Divider()
            
            // 输出目录归档区
            VStack(alignment: .leading, spacing: 8) {
                Text("输出保存目录")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.orange)
                    Text(viewModel.outputDirectory.lastPathComponent)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                
                Button(action: selectOutputDirectory) {
                    Label("更改目录", systemImage: "pencil.and.outline")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                
                Text("（建议选择外部 Downloads 目录以持久化自动保存）")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            .padding(.bottom, 10)
        }
        .padding(20)
        .frame(width: 220)
        .background(.ultraThinMaterial)
    }
    
    // 打开文件夹安全授权面板
    private func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择视频保存文件夹"
        openPanel.prompt = "授权此文件夹"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            viewModel.outputDirectory = url
        }
    }
}

// MARK: - 2. 顶部工具栏 (Single Responsibility)

struct TopControlBar: View {
    @ObservedObject var viewModel: ConvertViewModel
    
    var body: some View {
        HStack {
            if !viewModel.tasks.isEmpty {
                Button(action: { viewModel.clearCompleted() }) {
                    Label("清除已完成", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if viewModel.isConverting {
                Button(action: { viewModel.cancelAll() }) {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                        Text("停止转换")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { viewModel.startQueue() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始全部转换")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.tasks.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.2)) :
                        AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .foregroundStyle(viewModel.tasks.isEmpty ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.white))
                    .cornerRadius(8)
                    .shadow(color: viewModel.tasks.isEmpty ? .clear : .purple.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.tasks.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 3. 空状态下的文件拖拽区域 (Single Responsibility)

struct DragDropDropzone: View {
    var isDraggingOver: Bool
    var onSelectFiles: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(isDraggingOver ? AnyShapeStyle(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.gray.opacity(0.1)))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isDraggingOver ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isDraggingOver)
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(isDraggingOver ? .purple : .secondary)
            }
            
            VStack(spacing: 5) {
                Text("拖入视频文件至此")
                    .font(.system(size: 16, weight: .bold))
                Text("支持 MP4, MOV, MKV, AVI, WMV 等主流视频格式")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Button(action: onSelectFiles) {
                Text("选择文件")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isDraggingOver ? Color.purple : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(20)
        )
    }
}

// MARK: - 4. 任务列表容器 (Single Responsibility)

struct TaskListView: View {
    @ObservedObject var viewModel: ConvertViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.tasks.enumerated()), id: \.element.id) { index, task in
                    TaskCardView(
                        task: task,
                        isConverting: viewModel.isConverting,
                        onRemove: { viewModel.removeTask(at: index) }
                    )
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 5. 单个任务卡片视图 (Single Responsibility)

struct TaskCardView: View {
    let task: ConvertTask
    let isConverting: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // 状态图标指示组件
            TaskStatusIcon(status: task.status)
            
            VStack(alignment: .leading, spacing: 6) {
                // 文件名称与移除交互
                HStack {
                    Text(task.fileName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !isConverting {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 转换参数小标签
                HStack(spacing: 12) {
                    Text(task.targetFormat.rawValue)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                    
                    Text("分辨率: \(task.resolution.rawValue)")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .cornerRadius(4)
                    
                    if task.duration > 0 {
                        Text("时长: \(task.durationString)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !task.useHardwareAcceleration {
                        Text("CPU 软解")
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                }
                
                // 转码进度条组件
                if case .converting(let progress, let speed, _) = task.status {
                    VStack(spacing: 4) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.purple)
                        
                        HStack {
                            Text(String(format: "进度: %.1f%%", progress * 100))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("速度: \(speed)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 6. 任务状态图标组件 (Single Responsibility)

struct TaskStatusIcon: View {
    let status: ConvertStatus
    
    var body: some View {
        switch status {
        case .pending:
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "hourglass").font(.system(size: 12)).foregroundStyle(.secondary))
            
        case .converting:
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                .frame(width: 32, height: 32)
                .overlay(ProgressView().controlSize(.small).tint(.white))
            
        case .completed:
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.green))
            
        case .failed:
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "exclamationmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.red))
            
        case .cancelled:
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "minus").font(.system(size: 14, weight: .bold)).foregroundStyle(.orange))
        }
    }
}

// MARK: - 7. 实时极客控制台组件 (Single Responsibility)

struct GeekConsoleView: View {
    let logs: String
    @Binding var showLogs: Bool
    @Binding var consoleHeight: CGFloat
    
    @State private var dragBaseHeight: CGFloat = 0
    @State private var isHoveringResizer = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部的感应分隔条与标题栏
            ZStack(alignment: .top) {
                // 折叠/展开控制按钮
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showLogs.toggle() } }) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 12))
                        Text("实时调试日志")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: showLogs ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                }
                .buttonStyle(.plain)
                
                // 仅在展开时显示可拖拽的调整柄（悬浮在最顶层 6px 范围）
                if showLogs {
                    Rectangle()
                        .fill(isHoveringResizer ? Color.purple.opacity(0.4) : Color.clear)
                        .frame(height: 4)
                        .onHover { inside in
                            isHoveringResizer = inside
                            if inside {
                                NSCursor.resizeUpDown.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if dragBaseHeight == 0 {
                                        dragBaseHeight = consoleHeight
                                    }
                                    // 鼠标往上拉，Y坐标减少，高度增加
                                    let newHeight = dragBaseHeight - value.translation.height
                                    // 限制高度在 80px 至 450px 之间，提供最舒适的感官体验
                                    consoleHeight = min(max(newHeight, 80), 450)
                                }
                                .onEnded { _ in
                                    dragBaseHeight = 0
                                }
                        )
                }
            }
            
            if showLogs {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Text(logs.isEmpty ? "等待转换任务开始...\n" : logs)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .id("bottom")
                    }
                    .frame(height: consoleHeight)
                    .background(Color.black)
                    .onChange(of: logs) { _, _ in
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
