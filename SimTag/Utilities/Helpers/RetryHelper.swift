import Foundation

/// Utility for retrying async operations with exponential backoff
enum RetryHelper {
    /// Retry an async operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - initialDelay: Initial delay in seconds before first retry (default: 0.5)
    ///   - maxDelay: Maximum delay between retries in seconds (default: 5.0)
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation
    /// - Throws: The last error if all attempts fail
    static func retry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 5.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry on last attempt
                guard attempt < maxAttempts else { break }

                Logger.debug("Retry attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")

                // Wait with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Exponential backoff with max limit
                delay = min(delay * 2, maxDelay)
            }
        }

        // All attempts failed, throw the last error
        throw lastError ?? RetryError.allAttemptsFailed
    }

    /// Retry an async operation that returns an optional
    /// Returns nil if all attempts fail instead of throwing
    static func retryOptional<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 5.0,
        operation: () async throws -> T?
    ) async -> T? {
        do {
            return try await retry(
                maxAttempts: maxAttempts,
                initialDelay: initialDelay,
                maxDelay: maxDelay,
                operation: operation
            )
        } catch {
            Logger.warning("Retry failed after \(maxAttempts) attempts: \(error.localizedDescription)")
            return nil
        }
    }
}

enum RetryError: Error {
    case allAttemptsFailed
}
