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
                    if case let .converting(progress, speed, _) = task.status {
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
        }
    }
}
