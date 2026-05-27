//
//  TopControlBar.swift
//  VideoTool
//

import SwiftUI

struct TopControlBar: View {
    @ObservedObject var viewModel: ConvertViewModel

    var body: some View {
        HStack(spacing: 15) {
            // 左侧队列指示徽章
            if !viewModel.tasks.isEmpty {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isConverting ? Color.cyan : Color.purple)
                        .frame(width: 6, height: 6)
                        .shadow(color: viewModel.isConverting ? .cyan : .purple, radius: 4)

                    Text("队列任务: \(viewModel.tasks.count) 个")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                Button(action: { [weak viewModel] in
                    viewModel?.clearCompleted()
                }, label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("清空已完成")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
                .padding(.leading, 5)
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                    Text("控制中心就绪")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.isConverting {
                Button(action: { [weak viewModel] in
                    viewModel?.cancelAll()
                }, label: {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                            .tint(.white)
                        Text("终止转码")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(6)
                    .shadow(color: .red.opacity(0.35), radius: 6)
                })
                .buttonStyle(.plain)
            } else {
                Button(action: { [weak viewModel] in
                    viewModel?.startQueue()
                }, label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("开始全部转换")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        viewModel.tasks.isEmpty ?
                            AnyShapeStyle(Color.white.opacity(0.05)) :
                            AnyShapeStyle(
                                LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundStyle(viewModel.tasks.isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.6)) : AnyShapeStyle(Color.white))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(viewModel.tasks.isEmpty ? Color.white.opacity(0.04) : Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: viewModel.tasks.isEmpty ? .clear : .purple.opacity(0.35), radius: 8, x: 0, y: 3)
                })
                .buttonStyle(.plain)
                .disabled(viewModel.tasks.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}
