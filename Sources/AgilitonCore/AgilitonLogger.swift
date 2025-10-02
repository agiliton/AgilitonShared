import Foundation
import OSLog

// MARK: - Public Types

public enum AgilitonLogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case fatal = 4

    public static func < (lhs: AgilitonLogLevel, rhs: AgilitonLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fatal: return "💥"
        }
    }
}

public enum AgilitonLogCategory: String, CaseIterable, Sendable {
    case general = "General"
    case network = "Network"
    case database = "Database"
    case ui = "UI"
    case api = "API"
    case auth = "Auth"
    case storage = "Storage"
    case performance = "Performance"
    case test = "Test"
    // BestGPT-specific categories
    case knowledge = "Knowledge"
    case embedding = "Embedding"
    case similarity = "Similarity"
    case context = "Context"
    case persistence = "Persistence"
    case purchase = "Purchase"
    case fileAttachment = "FileAttachment"

    var logger: Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.agiliton", category: rawValue)
    }
}

public struct AgilitonLogEntry: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let level: AgilitonLogLevel
    public let category: AgilitonLogCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: Int

    public var fileName: String {
        (file as NSString).lastPathComponent
    }

    public var formattedMessage: String {
        "[\(category.rawValue)] [\(level)] \(message) [\(fileName):\(line)]"
    }
}

// MARK: - Logger

/// Enhanced AgilitonLogger with triple-layer logging for optimal Claude Code debugging
/// Layer 1: STDOUT (print) - Claude can read via BashOutput tool
/// Layer 2: File logging - Claude can read via Read tool
/// Layer 3: OSLog - Apple tools integration
public final class AgilitonLogger {

    // MARK: - Configuration

    public struct Configuration {
        public var enableFileLogging: Bool
        public var enableOSLogging: Bool
        public var enableConsoleOutput: Bool
        public var maxFileSize: Int
        public var logLevel: AgilitonLogLevel

        public init(
            enableFileLogging: Bool,
            enableOSLogging: Bool,
            enableConsoleOutput: Bool,
            maxFileSize: Int,
            logLevel: AgilitonLogLevel
        ) {
            self.enableFileLogging = enableFileLogging
            self.enableOSLogging = enableOSLogging
            self.enableConsoleOutput = enableConsoleOutput
            self.maxFileSize = maxFileSize
            self.logLevel = logLevel
        }

        public static let debug = Configuration(
            enableFileLogging: true,
            enableOSLogging: true,
            enableConsoleOutput: true,
            maxFileSize: 10,
            logLevel: .debug
        )

        public static let production = Configuration(
            enableFileLogging: false,
            enableOSLogging: true,
            enableConsoleOutput: false,
            maxFileSize: 5,
            logLevel: .info
        )
    }


    // MARK: - Singleton

    public static let shared = AgilitonLogger()

    // MARK: - Properties

    private var configuration: Configuration
    private let fileLogger: FileLogger?
    private let logQueue = DispatchQueue(label: "com.agiliton.logger", qos: .utility)

    // Test capture
    nonisolated(unsafe) private var capturedLogs: [AgilitonLogEntry] = []
    private var isCapturing = false

    // MARK: - Initialization

    private init() {
        #if DEBUG
        self.configuration = .debug
        #else
        self.configuration = .production
        #endif

        if configuration.enableFileLogging {
            self.fileLogger = FileLogger()
        } else {
            self.fileLogger = nil
        }
    }

    // MARK: - Configuration

    public func configure(_ configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - Logging Methods

    public func debug(_ message: String,
                     category: AgilitonLogCategory = .general,
                     context: [String: String]? = nil,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .debug, category: category, context: context, file: file, function: function, line: line)
    }

    public func info(_ message: String,
                    category: AgilitonLogCategory = .general,
                    context: [String: String]? = nil,
                    file: String = #file,
                    function: String = #function,
                    line: Int = #line) {
        log(message, level: .info, category: category, context: context, file: file, function: function, line: line)
    }

    public func warning(_ message: String,
                       category: AgilitonLogCategory = .general,
                       context: [String: String]? = nil,
                       file: String = #file,
                       function: String = #function,
                       line: Int = #line) {
        log(message, level: .warning, category: category, context: context, file: file, function: function, line: line)
    }

    public func error(_ message: String,
                     category: AgilitonLogCategory = .general,
                     context: [String: String]? = nil,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .error, category: category, context: context, file: file, function: function, line: line)
    }

    public func fatal(_ message: String,
                     category: AgilitonLogCategory = .general,
                     context: [String: String]? = nil,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .fatal, category: category, context: context, file: file, function: function, line: line)
    }

    // MARK: - Performance Tracking

    public func measure<T>(
        _ operationName: String,
        category: AgilitonLogCategory = .performance,
        level: AgilitonLogLevel = .debug,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)

        log(
            "⏱️ \(operationName) completed",
            level: level,
            category: category,
            context: [
                "operation": operationName,
                "durationMs": String(format: "%.2f", duration * 1000)
            ],
            file: #file,
            function: #function,
            line: #line
        )

        return result
    }

    // MARK: - Scoped Logging

    public func scoped(correlationId: String, category: AgilitonLogCategory = .general) -> ScopedLogger {
        ScopedLogger(logger: self, correlationId: correlationId, category: category)
    }

    // MARK: - Private Methods

    private func log(_ message: String,
                    level: AgilitonLogLevel,
                    category: AgilitonLogCategory,
                    context: [String: String]?,
                    file: String,
                    function: String,
                    line: Int) {

        guard level >= configuration.logLevel else { return }

        let filename = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Build context string
        var contextStr = ""
        if let context = context, !context.isEmpty {
            let contextPairs = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            contextStr = " [\(contextPairs)]"
        }

        // Triple-layer logging with enhanced formatting
        let consoleMessage = "\(level.emoji) [\(category.rawValue)] \(message)\(contextStr) (\(filename):\(line))"
        let fileMessage = "[\(timestamp)] [\(level)] [\(category.rawValue)] [\(filename):\(line)] \(function) - \(message)\(contextStr)"

        // Capture for tests if enabled
        if isCapturing {
            let entry = AgilitonLogEntry(
                timestamp: Date(),
                level: level,
                category: category,
                message: message,
                file: file,
                function: function,
                line: line
            )
            capturedLogs.append(entry)
        }

        logQueue.async { [weak self] in
            guard let self = self else { return }

            // Layer 1: STDOUT - Claude can read via BashOutput
            if self.configuration.enableConsoleOutput {
                print(consoleMessage)
            }

            // Layer 2: File - Claude can read via Read tool
            if self.configuration.enableFileLogging {
                self.fileLogger?.write(fileMessage)
            }

            // Layer 3: OSLog - Apple tools integration
            if self.configuration.enableOSLogging {
                self.logToOS(message: message, level: level, category: category)
            }
        }
    }

    private func logToOS(message: String, level: AgilitonLogLevel, category: AgilitonLogCategory) {
        let logger = category.logger
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .fatal:
            logger.fault("\(message, privacy: .public)")
        }
    }

    // MARK: - Test Capture

    public func startCapturingLogs() {
        isCapturing = true
        capturedLogs.removeAll()
    }

    public func stopCapturingLogs() {
        isCapturing = false
    }

    public func getCapturedLogs() -> [AgilitonLogEntry] {
        return capturedLogs
    }

    public func clearCapturedLogs() {
        capturedLogs.removeAll()
    }

    // MARK: - Log Retrieval

    public func getLogContents() -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first!
        let logFileURL = documentsPath
            .appendingPathComponent("Logs")
            .appendingPathComponent("app.log")

        return try? String(contentsOf: logFileURL)
    }

    public func getLogFileURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first!
        let logFileURL = documentsPath
            .appendingPathComponent("Logs")
            .appendingPathComponent("app.log")

        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return nil }
        return logFileURL
    }

    public func clearLogs() {
        fileLogger?.clear()
    }
}

// MARK: - FileLogger

private class FileLogger {
    private let logFileURL: URL
    private let maxFileSize: Int = 10 * 1024 * 1024

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")

        try? FileManager.default.createDirectory(at: logsDirectory,
                                                 withIntermediateDirectories: true)

        self.logFileURL = logsDirectory.appendingPathComponent("app.log")

        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        rotateIfNeeded()
    }

    func write(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }

        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }

        rotateIfNeeded()
    }

    func clear() {
        try? FileManager.default.removeItem(at: logFileURL)
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        write("=== LOGS CLEARED ===")
    }

    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxFileSize else { return }

        let backupURL = logFileURL.deletingPathExtension()
            .appendingPathExtension("old")
            .appendingPathExtension("log")

        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: logFileURL, to: backupURL)
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
}

// MARK: - ScopedLogger

/// Logger with correlation ID for request tracing
public class ScopedLogger {
    private let logger: AgilitonLogger
    private let correlationId: String
    private let category: AgilitonLogCategory

    init(logger: AgilitonLogger, correlationId: String, category: AgilitonLogCategory) {
        self.logger = logger
        self.correlationId = correlationId
        self.category = category
    }

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.debug(message, category: category, context: ["correlationId": correlationId], file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.info(message, category: category, context: ["correlationId": correlationId], file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.warning(message, category: category, context: ["correlationId": correlationId], file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error(message, category: category, context: ["correlationId": correlationId], file: file, function: function, line: line)
    }
}