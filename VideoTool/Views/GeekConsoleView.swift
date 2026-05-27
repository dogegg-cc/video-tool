//
//  GeekConsoleView.swift
//  VideoTool
//

import SwiftUI

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
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showLogs.toggle()
                    }
                }, label: {
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
                })
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
