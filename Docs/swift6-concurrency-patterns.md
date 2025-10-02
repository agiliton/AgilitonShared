# Swift 6 Concurrency Patterns for AgilitonLogger

## Overview

This document provides best practices for integrating AgilitonLogger in Swift 6 projects with strict concurrency checking enabled. These patterns emerged from real-world implementation in BestGPT.

## The Problem

When creating backward-compatible wrappers around `AgilitonLogger` in classes that use `@Observable`, you may encounter actor isolation conflicts:

```
error: passing closure as a 'sending' parameter risks causing data races
between main actor-isolated code and concurrent execution of the closure
```

## The Solution: `nonisolated` Methods

### Pattern 1: Wrapper Class with @Observable

When wrapping AgilitonLogger for backward compatibility in an `@Observable` class:

```swift
import AgilitonCore
import Observation

@available(iOS 17.0, *)
@Observable
final class LoggingService {
    // Use nonisolated(unsafe) for shared singleton
    nonisolated(unsafe) static let shared = LoggingService()

    private var minimumLevel: LogLevel = .debug

    private init() {}

    // CRITICAL: Mark ALL public logging methods as nonisolated
    nonisolated func debug(_ message: String,
                          category: Category = .general,
                          file: String = #file,
                          function: String = #function,
                          line: Int = #line) {
        AgilitonLogger.shared.debug(message,
                                   category: category.agilitonCategory,
                                   file: file,
                                   function: function,
                                   line: line)
    }

    nonisolated func info(_ message: String,
                         category: Category = .general,
                         file: String = #file,
                         function: String = #function,
                         line: Int = #line) {
        AgilitonLogger.shared.info(message,
                                  category: category.agilitonCategory,
                                  file: file,
                                  function: function,
                                  line: line)
    }

    // Also mark test capture methods as nonisolated
    nonisolated func startCapture() {
        AgilitonLogger.shared.startCapturingLogs()
    }

    nonisolated func getCaptured() -> [LogEntry] {
        // Map AgilitonLogEntry to LogEntry
        let agilitonLogs = AgilitonLogger.shared.getCapturedLogs()
        return agilitonLogs.compactMap { /* conversion */ }
    }
}
```

### Why This Works

1. **`@Observable` creates main actor isolation**: The macro automatically makes the class main actor-isolated to ensure thread-safe property observation

2. **`nonisolated` breaks the isolation**: By marking methods as `nonisolated`, they can be called from any isolation context

3. **`AgilitonLogger` is thread-safe**: AgilitonLogger uses internal synchronization (DispatchQueue), so it's safe to call from nonisolated contexts

4. **`nonisolated(unsafe)` for singletons**: The `static let shared` needs `nonisolated(unsafe)` to be accessible from non-main-actor contexts

## Pattern 2: Direct Usage in Concurrent Tests

When testing concurrent logging, access the shared instance directly without capturing:

```swift
func testConcurrentLogging() async {
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<10 {
            group.addTask {
                // ✅ Access shared instance directly
                LoggingService.shared.info("Concurrent \(i)")
            }
        }
    }

    let logs = LoggingService.shared.getCaptured()
    XCTAssertEqual(logs.count, 10)
}
```

**DON'T** capture the logger instance:

```swift
func testConcurrentLogging() async {
    let logger = LoggingService.shared  // ❌ Creates main-actor capture

    await withTaskGroup(of: Void.self) { group in
        for i in 0..<10 {
            group.addTask { [logger] in  // ❌ Causes data race warning
                await logger.info("Concurrent \(i)")
            }
        }
    }
}
```

## Pattern 3: Category Mapping

When wrapping AgilitonLogger categories:

```swift
enum Category: String, Sendable {
    case api = "API"
    case knowledge = "Knowledge"
    case embedding = "Embedding"
    // ... more categories

    var agilitonCategory: AgilitonLogCategory {
        switch self {
        case .api: return .api
        case .knowledge: return .knowledge
        case .embedding: return .embedding
        // ... more mappings
        }
    }
}
```

**Key**: The local enum must be `Sendable` to work in concurrent contexts.

## Pattern 4: Log Entry Conversion

When converting between AgilitonLogEntry and your local LogEntry type:

```swift
struct LogEntry: Sendable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: Category
    let message: String
    let file: String
    let function: String
    let line: Int

    // CRITICAL: Don't set id in init, it's auto-generated
    init(from agilitonEntry: AgilitonLogEntry,
         legacyLevel: LogLevel,
         legacyCategory: Category) {
        self.timestamp = agilitonEntry.timestamp
        self.level = legacyLevel
        self.category = legacyCategory
        self.message = agilitonEntry.message
        self.file = agilitonEntry.file
        self.function = agilitonEntry.function
        self.line = agilitonEntry.line
        // Don't set self.id = agilitonEntry.id
        // UUID is generated automatically
    }
}
```

## Common Pitfalls

### ❌ Pitfall 1: Forgetting `nonisolated`

```swift
@Observable
final class LoggingService {
    // Missing nonisolated
    func info(_ message: String) {
        AgilitonLogger.shared.info(message)
    }
}

// Later in concurrent code:
group.addTask {
    logger.info("Test")  // ❌ Error: main actor-isolated
}
```

### ❌ Pitfall 2: Using `await` When Not Needed

```swift
nonisolated func info(_ message: String) {
    // ❌ Don't use await, AgilitonLogger methods aren't async
    await AgilitonLogger.shared.info(message)
}

// ✅ Correct:
nonisolated func info(_ message: String) {
    AgilitonLogger.shared.info(message)
}
```

### ❌ Pitfall 3: Capturing Logger in Concurrent Closures

```swift
let logger = LoggingService.shared
group.addTask { [logger] in  // ❌ Captures main-actor-isolated value
    logger.info("Test")
}

// ✅ Correct: Access directly
group.addTask {
    LoggingService.shared.info("Test")
}
```

## Verification Checklist

When integrating AgilitonLogger in a new project:

- [ ] All public logging methods marked `nonisolated`
- [ ] Test capture methods (`startCapture`, `getCaptured`, `clearCaptured`) marked `nonisolated`
- [ ] Category enum marked `Sendable`
- [ ] LogEntry struct marked `Sendable`
- [ ] LogLevel enum marked `Sendable`
- [ ] Shared singleton uses `nonisolated(unsafe) static let shared`
- [ ] No `await` used for synchronous AgilitonLogger methods
- [ ] Concurrent tests access `.shared` directly, not via captures
- [ ] UUID auto-generation not overridden in LogEntry init

## Real-World Example: BestGPT

See the complete implementation in:
- `/Users/christian.gick/VisualStudio/BestGPT/AgilitonBestGPT/LoggingService.swift`
- `/Users/christian.gick/VisualStudio/BestGPT/AgilitonBestGPTTests/Services/LoggingServiceTests.swift`

This implementation successfully passes all 113 unit tests with Swift 6 strict concurrency checking.

## Additional Resources

- [Swift Concurrency Proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
- [Sendable and @Sendable closures](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- [Main Actor Usage](https://developer.apple.com/documentation/swift/mainactor)

---

**Last Updated**: October 2, 2025
**Version**: 1.0.0
**Tested With**: Swift 6, iOS 26.0, Xcode 16
