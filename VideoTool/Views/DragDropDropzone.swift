//
//  DragDropDropzone.swift
//  VideoTool
//

import SwiftUI

struct DragDropDropzone: View {
    var isDraggingOver: Bool
    var onSelectFiles: () -> Void

    @State private var rotationAngle: Double = 0
    @State private var breathScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 25) {
            ZStack {
                // 外层旋转虚线圈
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotationAngle) // 隔离动画，防止泄露给其它视图
                    .onAppear {
                        rotationAngle = 360
                    }

                // 内层呼吸感应光圈
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(isDraggingOver ? 0.25 : 0.08), Color.purple.opacity(isDraggingOver ? 0.25 : 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(isDraggingOver ? 1.1 : breathScale)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: breathScale) // 隔离呼吸动画
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isDraggingOver)
                    .onAppear {
                        if !isDraggingOver {
                            breathScale = 1.05
                        }
                    }

                // 中心发光图标
                Image(systemName: isDraggingOver ? "arrow.down.doc.fill" : "video.badge.plus")
                    .font(.system(size: 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .cyan.opacity(0.6), radius: 8)
            }
            .padding(.top, 20)

            VStack(spacing: 8) {
                Text("拖入视频文件至此")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text("支持 MP4, HEVC (H.265), MOV (ProRes), MKV, GIF, MP3 等格式")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Button(action: onSelectFiles) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.rectangle.on.folder.fill")
                    Text("选择媒体文件")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(6)
                .shadow(color: .purple.opacity(0.35), radius: 6)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isDraggingOver ? Color.cyan : Color.cyan.opacity(0.2),
                            isDraggingOver ? Color.purple : Color.purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 4])
                )
                .padding(20)
        )
    }
}
