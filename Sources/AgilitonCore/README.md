# AgilitonCore

Core infrastructure components shared across all Agiliton projects.

## AgilitonLogger - Claude Code Optimized Logging

### Overview

AgilitonLogger provides comprehensive logging with a **triple-layer architecture** specifically optimized for autonomous debugging by Claude Code and other AI coding assistants.

### Triple-Layer Logging Architecture

AgilitonLogger uses three complementary layers to ensure logs are accessible in every development scenario:

```
┌─────────────────────────────────────────────────────────────────┐
│                      AgilitonLogger                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Layer 1: STDOUT (print)                                        │
│  ├─ Format: 🔍 [Category] Message (File.swift:42)              │
│  ├─ Access: BashOutput tool                                     │
│  └─ Use Case: Real-time debugging during app execution          │
│                                                                   │
│  Layer 2: File Logging                                          │
│  ├─ Location: ~/Documents/Logs/app.log                          │
│  ├─ Format: [ISO8601] [LEVEL] [Category] [File:Line] Message   │
│  ├─ Access: Read tool                                           │
│  ├─ Rotation: 10MB max                                          │
│  └─ Use Case: Historical log analysis, crash investigation      │
│                                                                   │
│  Layer 3: OSLog                                                  │
│  ├─ Subsystem: Bundle identifier                                │
│  ├─ Categories: API, UI, Database, etc.                         │
│  ├─ Access: Console.app, Instruments                            │
│  └─ Use Case: Apple development tools, performance profiling    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Why Not OSLogStore?

We researched using `OSLogStore` API for programmatic log access, but discovered critical limitations:

**OSLogStore Limitations:**
- Only returns logs **after** the last app launch
- Cannot access real-time logs during current session
- Requires special entitlements
- Position-based API is fragile across system updates

**Our Solution:**
- STDOUT: Immediate access via `BashOutput` tool
- File: Persistent across sessions, no entitlements needed
- OSLog: Still available for traditional tools

This triple-layer approach ensures Claude Code can always access logs for autonomous debugging.

### Basic Usage

```swift
import AgilitonCore

// Simple logging
AgilitonLogger.shared.debug("Starting operation")
AgilitonLogger.shared.info("User logged in successfully")
AgilitonLogger.shared.warning("Cache miss, fetching from network")
AgilitonLogger.shared.error("Failed to save data")

// With categories
AgilitonLogger.shared.info("API call completed",
                          category: .network)

// With context
AgilitonLogger.shared.error("Database write failed",
                           category: .database,
                           context: ["table": "users", "operation": "insert"])
```

### Available Categories

```swift
public enum AgilitonLogCategory: String {
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
}
```

### Log Levels

```swift
public enum AgilitonLogLevel: Int, Comparable {
    case debug = 0      // 🔍 Detailed debugging information
    case info = 1       // ℹ️  General informational messages
    case warning = 2    // ⚠️  Warning conditions
    case error = 3      // ❌ Error conditions
    case fatal = 4      // 💥 Fatal errors (app should terminate)
}
```

### Configuration

```swift
// Debug configuration (default in DEBUG builds)
let debugConfig = AgilitonLogger.Configuration(
    enableFileLogging: true,
    enableOSLogging: true,
    enableConsoleOutput: true,
    maxFileSize: 10,  // MB
    logLevel: .debug
)

// Production configuration (default in RELEASE builds)
let productionConfig = AgilitonLogger.Configuration(
    enableFileLogging: false,
    enableOSLogging: true,
    enableConsoleOutput: false,
    maxFileSize: 5,
    logLevel: .info
)

// Apply configuration
AgilitonLogger.shared.configure(debugConfig)
```

### Performance Tracking

Track operation performance automatically:

```swift
let result = await AgilitonLogger.shared.measure("Fetch user data") {
    await fetchUserData()
}

// Logs: ⏱️ Fetch user data completed [operation=Fetch user data, durationMs=245.67]
```

### Scoped Logging

Create scoped loggers for request tracing:

```swift
func handleAPIRequest(id: String) async {
    let logger = AgilitonLogger.shared.scoped(
        correlationId: id,
        category: .api
    )

    logger.info("Request started")
    // ... process request
    logger.info("Request completed")
}

// All logs include correlationId in context
```

### Test Capture

Capture logs for unit testing:

```swift
func testUserLogin() {
    // Start capturing
    AgilitonLogger.shared.startCapturingLogs()

    // Run code that logs
    loginService.login(username: "test", password: "pass")

    // Retrieve captured logs
    let logs = AgilitonLogger.shared.getCapturedLogs()

    // Assert
    XCTAssertEqual(logs.count, 3)
    XCTAssertEqual(logs.first?.level, .info)
    XCTAssertEqual(logs.first?.message, "Login attempt started")

    // Cleanup
    AgilitonLogger.shared.clearCapturedLogs()
}
```

### File Log Access

```swift
// Get log file URL
if let logURL = AgilitonLogger.shared.getLogFileURL() {
    print("Logs available at: \(logURL.path)")
}

// Get log contents as string
if let contents = AgilitonLogger.shared.getLogContents() {
    print(contents)
}

// Clear all logs
AgilitonLogger.shared.clearLogs()
```

### Integration with Claude Code

When Claude Code runs your app, it can access logs via:

**1. Real-time via STDOUT:**
```bash
# Claude runs app in background
swift run &

# Read output as it becomes available
BashOutput <shell_id>
```

**2. Historical via File:**
```bash
# Read log file directly
Read ~/Documents/Logs/app.log
```

**3. Search logs:**
```bash
# Find specific errors
Grep pattern:"error.*database" path:~/Documents/Logs/app.log
```

### Best Practices

1. **Use appropriate log levels:**
   - `debug`: Only for detailed debugging (removed in production)
   - `info`: General flow information
   - `warning`: Recoverable issues
   - `error`: Failures requiring attention
   - `fatal`: Critical failures

2. **Include context:**
   ```swift
   // ❌ Bad
   logger.error("Save failed")

   // ✅ Good
   logger.error("Save failed", context: [
       "entity": "User",
       "id": userId,
       "error": error.localizedDescription
   ])
   ```

3. **Use categories consistently:**
   ```swift
   // ✅ Use semantic categories
   logger.info("API response received", category: .network)
   logger.info("Cache updated", category: .storage)
   logger.info("View appeared", category: .ui)
   ```

4. **Capture in tests:**
   ```swift
   override func setUp() async throws {
       try await super.setUp()
       AgilitonLogger.shared.startCapturingLogs()
   }

   override func tearDown() async throws {
       AgilitonLogger.shared.clearCapturedLogs()
       try await super.tearDown()
   }
   ```

5. **Performance tracking:**
   ```swift
   // Track expensive operations
   let data = await logger.measure("Database query") {
       await database.fetchAll()
   }
   ```

### Swift 6 Concurrency

AgilitonLogger is fully compatible with Swift 6 strict concurrency:

- All public types are `Sendable`
- Thread-safe via internal `DispatchQueue`
- Can be called from any isolation context
- No `@MainActor` requirements

See [swift6-concurrency-patterns.md](../../Docs/swift6-concurrency-patterns.md) for integration patterns.

### Migration from Basic Logging

If you're migrating from `print()` statements:

```swift
// Before
print("User logged in: \(username)")

// After
AgilitonLogger.shared.info("User logged in",
                          category: .auth,
                          context: ["username": username])
```

### Troubleshooting

**Logs not appearing in Console.app:**
- Check OSLog is enabled: `configuration.enableOSLogging = true`
- Verify subsystem matches bundle ID
- Use Console.app filter: `subsystem:com.agiliton.yourapp`

**File logging not working:**
- Check permissions for Documents directory
- Verify `configuration.enableFileLogging = true`
- Check `getLogFileURL()` returns valid path

**Claude Code can't see logs:**
- STDOUT: Ensure `configuration.enableConsoleOutput = true`
- File: Check `getLogFileURL()` and verify file exists
- Background processes: Use `run_in_background` for long-running tasks

---

**Version**: 2.0.0
**Last Updated**: October 2, 2025
**Optimized for**: Claude Code autonomous debugging
