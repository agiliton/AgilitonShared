import Foundation
import OSLog

public final class AgilitonLogger {

    // MARK: - Configuration

    public struct Configuration {
        public var enableFileLogging: Bool
        public var enableOSLogging: Bool
        public var enableConsoleOutput: Bool
        public var maxFileSize: Int
        public var logLevel: LogLevel

        public init(
            enableFileLogging: Bool,
            enableOSLogging: Bool,
            enableConsoleOutput: Bool,
            maxFileSize: Int,
            logLevel: LogLevel
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

    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case fatal = 4

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Singleton

    public static let shared = AgilitonLogger()

    // MARK: - Properties

    private var configuration: Configuration
    private let osLogger: Logger
    private let fileLogger: FileLogger?
    private let logQueue = DispatchQueue(label: "com.agiliton.logger", qos: .utility)

    // MARK: - Initialization

    private init() {
        #if DEBUG
        self.configuration = .debug
        #else
        self.configuration = .production
        #endif

        self.osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.agiliton",
                               category: "general")

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
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    public func info(_ message: String,
                    file: String = #file,
                    function: String = #function,
                    line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    public func warning(_ message: String,
                       file: String = #file,
                       function: String = #function,
                       line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    public func error(_ message: String,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    public func fatal(_ message: String,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .fatal, file: file, function: function, line: line)
    }

    // MARK: - Private Methods

    private func log(_ message: String,
                    level: LogLevel,
                    file: String,
                    function: String,
                    line: Int) {

        guard level >= configuration.logLevel else { return }

        let filename = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let logMessage = "[\(timestamp)] [\(level)] [\(filename):\(line)] \(function) - \(message)"

        logQueue.async { [weak self] in
            guard let self = self else { return }

            if self.configuration.enableConsoleOutput {
                print(logMessage)
            }

            if self.configuration.enableOSLogging {
                self.logToOS(message: message, level: level)
            }

            if self.configuration.enableFileLogging {
                self.fileLogger?.write(logMessage)
            }
        }
    }

    private func logToOS(message: String, level: LogLevel) {
        switch level {
        case .debug:
            osLogger.debug("\(message)")
        case .info:
            osLogger.info("\(message)")
        case .warning:
            osLogger.warning("\(message)")
        case .error:
            osLogger.error("\(message)")
        case .fatal:
            osLogger.fault("\(message)")
        }
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