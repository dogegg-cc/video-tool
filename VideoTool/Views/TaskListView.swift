//
//  TaskListView.swift
//  VideoTool
//

import SwiftUI

struct TaskListView: View {
    @ObservedObject var viewModel: ConvertViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.tasks.enumerated()), id: \.element.id) { index, task in
                    TaskCardView(
                        task: task,
                        isConverting: viewModel.isConverting,
                        onRemove: { [weak viewModel] in
                            viewModel?.removeTask(at: index)
                        }
                    )
                }
            }
            .padding(20)
        }
    }
}
