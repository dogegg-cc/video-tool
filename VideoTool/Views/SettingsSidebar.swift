//
//  SettingsSidebar.swift
//  VideoTool
//

import SwiftUI

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
