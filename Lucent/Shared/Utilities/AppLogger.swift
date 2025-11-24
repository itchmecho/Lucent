//
//  AppLogger.swift
//  Lucent
//
//  Created by Claude Code on 11/24/24.
//

import Foundation
import os.log

/// Centralized logging utility for the Lucent app
///
/// This class provides structured logging using Apple's unified logging system (OSLog).
/// Log messages are categorized by subsystem and category for better organization and filtering.
///
/// Usage:
/// ```swift
/// AppLogger.auth.info("User authenticated successfully")
/// AppLogger.storage.error("Failed to save photo: \(error.localizedDescription)")
/// ```
enum AppLogger {

    // MARK: - Loggers

    /// Logger for authentication-related events
    static let auth = Logger(subsystem: subsystem, category: "Authentication")

    /// Logger for storage and photo management events
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// Logger for encryption and security events
    static let security = Logger(subsystem: subsystem, category: "Security")

    /// Logger for UI and view-related events
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Logger for general app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Logger for import/export operations
    static let importExport = Logger(subsystem: subsystem, category: "ImportExport")

    /// Logger for settings and preferences
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    // MARK: - Private Properties

    private static let subsystem = "com.lucent.app"
}

// MARK: - Logging Levels

extension Logger {

    /// Log a debug message (lowest priority, for development only)
    ///
    /// Debug messages are not persisted and are only visible during active debugging
    ///
    /// - Parameter message: The message to log
    func debug(_ message: String) {
        self.debug("\(message, privacy: .public)")
    }

    /// Log an info message (informational, normal operation)
    ///
    /// Info messages help track the app's normal operation flow
    ///
    /// - Parameter message: The message to log
    func info(_ message: String) {
        self.info("\(message, privacy: .public)")
    }

    /// Log a warning message (unexpected but recoverable)
    ///
    /// Warnings indicate potential issues that don't prevent operation
    ///
    /// - Parameter message: The message to log
    func warning(_ message: String) {
        self.warning("\(message, privacy: .public)")
    }

    /// Log an error message (error that prevents normal operation)
    ///
    /// Errors indicate failures that prevent the intended operation
    ///
    /// - Parameter message: The message to log
    func error(_ message: String) {
        self.error("\(message, privacy: .public)")
    }

    /// Log a critical error (serious error requiring immediate attention)
    ///
    /// Critical messages indicate severe failures that may cause data loss
    ///
    /// - Parameter message: The message to log
    func critical(_ message: String) {
        self.critical("\(message, privacy: .public)")
    }
}
