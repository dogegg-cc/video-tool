//
//  SettingsSidebar.swift
//  VideoTool
//

import SwiftUI

struct SettingsSidebar: View {
    @ObservedObject var viewModel: ConvertViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题区 (带未来科技感发光点)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("格式大师")
                        .font(.system(size: 14, weight: .bold))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                        Text("CYBER CORE V1.0")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 10)

            Divider()
                .background(Color.white.opacity(0.08))

            // 参数配置预设区
            VStack(alignment: .leading, spacing: 18) {
                // 目标格式选择 (自定义科技感网格选择)
                VStack(alignment: .leading, spacing: 8) {
                    Text("目标转码格式")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(VideoFormat.allCases) { format in
                            Button(action: {
                                viewModel.globalFormat = format
                            }) {
                                Text(format.shortLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(viewModel.globalFormat == format ? Color.cyan.opacity(0.12) : Color.black.opacity(0.2))
                                    .foregroundStyle(viewModel.globalFormat == format ? Color.cyan : Color.secondary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(viewModel.globalFormat == format ? Color.cyan.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(color: viewModel.globalFormat == format ? Color.cyan.opacity(0.15) : Color.clear, radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 目标分辨率选择 (自定义列表选择)
                VStack(alignment: .leading, spacing: 8) {
                    Text("目标分辨率")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 6) {
                        ForEach(VideoResolution.allCases) { resolution in
                            Button(action: {
                                viewModel.globalResolution = resolution
                            }) {
                                HStack {
                                    Text(resolution.label)
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    if viewModel.globalResolution == resolution {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 6, height: 6)
                                            .shadow(color: .purple, radius: 4)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(viewModel.globalResolution == resolution ? Color.purple.opacity(0.12) : Color.black.opacity(0.15))
                                .foregroundStyle(viewModel.globalResolution == resolution ? Color.purple : Color.primary.opacity(0.8))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(viewModel.globalResolution == resolution ? Color.purple.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 硬件加速切换 (自定义极光控制Toggle)
                Button(action: {
                    viewModel.globalHardwareAccel.toggle()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("苹果硬件加速")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("VideoToolbox 极速引擎")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ZStack(alignment: viewModel.globalHardwareAccel ? .trailing : .leading) {
                            Capsule()
                                .fill(viewModel.globalHardwareAccel ? Color.cyan.opacity(0.2) : Color.black.opacity(0.3))
                                .frame(width: 34, height: 18)
                                .overlay(
                                    Capsule()
                                        .stroke(viewModel.globalHardwareAccel ? Color.cyan.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )

                            Circle()
                                .fill(viewModel.globalHardwareAccel ? Color.cyan : Color.gray)
                                .frame(width: 12, height: 12)
                                .padding(.horizontal, 3)
                                .shadow(color: viewModel.globalHardwareAccel ? .cyan : .clear, radius: 4)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Divider()
                .background(Color.white.opacity(0.08))

            // 输出目录归档区
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("输出目录")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "folder.fill.badge.gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                            )
                        Text(viewModel.outputDirectory.lastPathComponent)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }

                    Button(action: selectOutputDirectory) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("重设导出目录")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
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
