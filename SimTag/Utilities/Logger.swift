import Foundation

/// Simple logging utility with debug/production modes
enum Logger {
    /// Log debug message (only shown in Debug builds)
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("DEBUG [\(filename):\(line)] \(message)")
        #endif
    }

    /// Log info message (always shown)
    static func info(_ message: String) {
        print("INFO: \(message)")
    }

    /// Log warning message (always shown)
    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("WARNING [\(filename):\(line)] \(message)")
    }

    /// Log error message (always shown)
    static func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        var logMessage = "ERROR [\(filename):\(line)] \(message)"
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        print(logMessage)
    }
}
