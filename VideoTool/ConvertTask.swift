//
//  ConvertTask.swift
//  VideoTool
//

import Foundation

enum ConvertStatus: Equatable {
    case pending
    case converting(progress: Double, speed: String, eta: String)
    case completed
    case failed(error: String)
    case cancelled

    static func == (lhs: ConvertStatus, rhs: ConvertStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): true
        case (.completed, .completed): true
        case (.cancelled, .cancelled): true
        case let (.failed(lErr), .failed(rErr)): lErr == rErr
        case let (.converting(lProg, lSpd, lEta), .converting(rProg, rSpd, rEta)):
            lProg == rProg && lSpd == rSpd && lEta == rEta
        default: false
        }
    }
}

enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4 (H.264)"
    case hevc = "MP4 (H.265)"
    case mkv = "MKV"
    case mov = "MOV (ProRes)"
    case gif = "GIF 动图"
    case mp3 = "MP3 (仅音频)"

    var id: String { rawValue }
    var extensionName: String {
        switch self {
        case .mp4, .hevc: "mp4"
        case .mkv: "mkv"
        case .mov: "mov"
        case .gif: "gif"
        case .mp3: "mp3"
        }
    }
}

enum VideoResolution: String, CaseIterable, Identifiable {
    case original = "保持原样"
    case p1080 = "1080P"
    case p720 = "720P"
    case p480 = "480P"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: "保持原样"
        case .p1080: "1080P (1920x1080)"
        case .p720: "720P (1280x720)"
        case .p480: "480P (854x480)"
        }
    }

    var scaleArgument: String? {
        switch self {
        case .original: nil
        case .p1080: " -vf scale=-2:1080"
        case .p720: " -vf scale=-2:720"
        case .p480: " -vf scale=-2:480"
        }
    }
}

struct ConvertTask: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var targetFormat: VideoFormat
    var resolution: VideoResolution = .original
    var useHardwareAcceleration: Bool = true

    var targetURL: URL?
    var status: ConvertStatus = .pending
    var duration: Double = 0.0 // 视频总时长（秒）

    var fileName: String {
        sourceURL.lastPathComponent
    }

    // 智能将 Double 秒数转化为“小时、分钟、秒”的可读中文字符串
    var durationString: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分\(seconds)秒"
        } else if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    // 获取源视频的物理文件大小，安全兼容 macOS 沙盒环境
    var fileSizeString: String {
        let isScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
              let size = attributes[.size] as? Int64
        else {
            return ""
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
