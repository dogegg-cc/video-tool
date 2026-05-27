//
//  TaskStatusIcon.swift
//  VideoTool
//

import SwiftUI

struct TaskStatusIcon: View {
    let status: ConvertStatus

    var body: some View {
        switch status {
        case .pending:
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "hourglass").font(.system(size: 12)).foregroundStyle(.secondary))

        case .converting:
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                .frame(width: 32, height: 32)
                .overlay(ProgressView().controlSize(.small).tint(.white))

        case .completed:
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.green))

        case .failed:
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "exclamationmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.red))

        case .cancelled:
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "minus").font(.system(size: 14, weight: .bold)).foregroundStyle(.orange))
        }
    }
}
