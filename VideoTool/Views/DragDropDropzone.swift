//
//  DragDropDropzone.swift
//  VideoTool
//

import SwiftUI

struct DragDropDropzone: View {
    var isDraggingOver: Bool
    var onSelectFiles: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(
                        isDraggingOver ?
                            AnyShapeStyle(LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )) :
                            AnyShapeStyle(Color.gray.opacity(0.1))
                    )
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
