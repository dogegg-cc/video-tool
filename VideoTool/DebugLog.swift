//
//  DebugLog.swift
//  VideoTool
//

import Foundation
import os.log

enum DebugLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "cc.dogegg.videotool"
    private static let logger = Logger(subsystem: subsystem, category: "VideoTool")

    static func info(_ message: String) {
        #if DEBUG
            logger.info("\(message, privacy: .public)")
        #endif
    }

    static func error(_ message: String) {
        #if DEBUG
            logger.error("\(message, privacy: .public)")
        #endif
    }

    static func debug(_ message: String) {
        #if DEBUG
            logger.debug("\(message, privacy: .public)")
        #endif
    }
}
