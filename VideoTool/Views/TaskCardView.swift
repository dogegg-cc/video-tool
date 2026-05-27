//
//  TaskCardView.swift
//  VideoTool
//

import SwiftUI

struct TaskCardView: View {
    let task: ConvertTask
    let isConverting: Bool
    let onRemove: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                // 状态图标指示组件 (带呼吸/旋转动画)
                TaskStatusIcon(status: task.status)

                VStack(alignment: .leading, spacing: 8) {
                    // 文件名称与移除交互
                    HStack {
                        Text(task.fileName)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        if !isConverting {
                            Button(action: onRemove) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 转换参数小标签 (科幻代码微标签)
                    HStack(spacing: 8) {
                        Text(task.targetFormat.extensionName.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.1))
                            .foregroundStyle(.cyan)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                            )

                        Text(task.resolution.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                            )

                        if task.duration > 0 {
                            Text("视频时长: \(task.durationString)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.2))
                                .foregroundStyle(.secondary)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }

                        if !task.fileSizeString.isEmpty {
                            Text("大小: \(task.fileSizeString)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.2))
                                .foregroundStyle(.secondary)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }

                        if !task.useHardwareAcceleration {
                            Text("CPU 软解")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // 转码进度条组件 (全自研霓虹呼吸进度条)
                    if case let .converting(progress, speed, _) = task.status {
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.black.opacity(0.35))
                                        .frame(height: 5)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        )

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(progress), height: 5)
                                        .shadow(color: .purple.opacity(0.5), radius: 4)
                                }
                            }
                            .frame(height: 5)
                            .padding(.top, 2)

                            HStack {
                                Text(String(format: "转换进度: %.1f%%", progress * 100))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.cyan)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 8))
                                    Text("转换速度: \(speed)")
                                }
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}
