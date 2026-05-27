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
            SettingsSidebar(viewModel: viewModel)

            VStack(spacing: 0) {
                TopControlBar(viewModel: viewModel)

                ZStack {
                    Color.black.opacity(0.05).ignoresSafeArea()

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
        .frame(minWidth: 800, minHeight: 520)
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
