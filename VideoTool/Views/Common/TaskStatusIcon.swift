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
            PendingIndicator()

        case .converting:
            ConvertingIndicator()

        case .completed:
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                )
                .shadow(color: .green.opacity(0.3), radius: 6)

        case .failed:
            Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                )
                .shadow(color: .red.opacity(0.3), radius: 6)

        case .cancelled:
            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                )
                .shadow(color: .orange.opacity(0.2), radius: 4)
        }
    }
}

// MARK: - 高科技动效子视图 (Subviews)

struct ConvertingIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: rotation) // 隔离旋转动画
                .onAppear {
                    rotation = 360
                }

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.cyan)
        }
        .frame(width: 32, height: 32)
        .shadow(color: .purple.opacity(0.4), radius: 5)
    }
}

struct PendingIndicator: View {
    @State private var isPulseActive = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 32, height: 32)

            Circle()
                .stroke(Color.cyan.opacity(0.45), lineWidth: 1)
                .frame(width: 26, height: 26)
                .scaleEffect(isPulseActive ? 1.15 : 0.95)
                .opacity(isPulseActive ? 0.3 : 0.95)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulseActive) // 隔离呼吸虚光动画

            Image(systemName: "hourglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.cyan)
        }
        .frame(width: 32, height: 32)
        .onAppear {
            isPulseActive = true
        }
        .shadow(color: .cyan.opacity(0.15), radius: 4)
    }
}
