import XCTest

/// Extensions to make async testing easier
public extension XCTestCase {

    /// Wait for an async condition with timeout
    func waitFor<T>(
        _ expression: @escaping () async throws -> T,
        toEqual expected: T,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) where T: Equatable {
        let expectation = expectation(description: "Waiting for \(expected)")

        Task {
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < timeout {
                do {
                    let value = try await expression()
                    if value == expected {
                        expectation.fulfill()
                        return
                    }
                } catch {
                    // Continue waiting
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        wait(for: [expectation], timeout: timeout + 1)
    }

    /// Assert async throwing expression doesn't throw
    func assertNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("Expression threw error: \(error)", file: file, line: line)
        }
    }

    /// Assert async expression throws specific error
    func assertThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expression did not throw", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Wrong error type: \(error)", file: file, line: line)
        }
    }
}

// Mock URLSession removed - use URLProtocol for mocking instead

/// Test fixture builder for common models
public protocol TestFixture {
    static func fixture() -> Self
}

/// Memory leak detection
public extension XCTestCase {
    func assertNoMemoryLeak(_ instance: AnyObject,
                           file: StaticString = #file,
                           line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated", file: file, line: line)
        }
    }
}