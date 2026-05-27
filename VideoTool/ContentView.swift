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
        ZStack {
            // 底层深海极光暗黑色背景
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            // 极客青 (Cyber Cyan) 氛围光晕
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -150, y: -100)

            // 迷幻紫 (Neon Purple) 氛围光晕
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 200, y: 120)

            // 主应用布局
            HStack(spacing: 0) {
                SettingsSidebar(viewModel: viewModel)

                VStack(spacing: 0) {
                    TopControlBar(viewModel: viewModel)

                    ZStack {
                        // 曜石暗色卡片槽背景
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()

                        if viewModel.tasks.isEmpty {
                            DragDropDropzone(isDraggingOver: isDraggingOver, onSelectFiles: selectFiles)
                        } else {
                            TaskListView(viewModel: viewModel)
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                        handleDrop(providers: providers)
                    }

                    GeekConsoleView(logs: viewModel.logs, showLogs: $showLogs, consoleHeight: $consoleHeight)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        .preferredColorScheme(.dark) // 强制开启暗黑模式，解决系统浅色模式下文字发黑看不清的问题
    }

    // MARK: - 辅助交互 (零计算 Body)

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        viewModel.addVideo(url: url)
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

#Preview {
    ContentView()
}
