//
//  TopControlBar.swift
//  VideoTool
//

import SwiftUI

struct TopControlBar: View {
    @ObservedObject var viewModel: ConvertViewModel

    var body: some View {
        HStack {
            if !viewModel.tasks.isEmpty {
                Button(action: { [weak viewModel] in
                    viewModel?.clearCompleted()
                }, label: {
                    Label("清除已完成", systemImage: "trash")
                })
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
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
                        Text("停止转换")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .cornerRadius(6)
                })
                .buttonStyle(.plain)
            } else {
                Button(action: { [weak viewModel] in
                    viewModel?.startQueue()
                }, label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始全部转换")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.tasks.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.2)) :
                            AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .foregroundStyle(viewModel.tasks.isEmpty ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.white))
                    .cornerRadius(8)
                    .shadow(color: viewModel.tasks.isEmpty ? .clear : .purple.opacity(0.3), radius: 5, x: 0, y: 2)
                })
                .buttonStyle(.plain)
                .disabled(viewModel.tasks.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(.ultraThinMaterial)
    }
}
