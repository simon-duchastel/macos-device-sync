import Foundation

class Logger {
    static let shared = Logger()
    private(set) var logs: [String] = []
    private let maxLogs = 1000
    private let logFileURL: URL?
    
    private init() {
        // Setup file logging
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("BTAutoConnect", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            logFileURL = dir.appendingPathComponent("debug.log")
        } else {
            logFileURL = nil
        }
        
        log("Logger initialized. File: \(logFileURL?.path ?? "N/A")")
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        // Always write to file first
        if let url = logFileURL {
            let entry = logEntry + "\n"
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    _ = handle.seekToEndOfFile()
                    handle.write(entry.data(using: .utf8)!)
                    try? handle.close()
                }
            } else {
                try? entry.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        
        // Then update in-memory logs
        DispatchQueue.main.async { [weak self] in
            self?.logs.append(logEntry)
            if let count = self?.logs.count, count > self?.maxLogs ?? 1000 {
                self?.logs.removeFirst(count - (self?.maxLogs ?? 1000))
            }
            NotificationCenter.default.post(name: .loggerDidUpdate, object: nil)
        }
        
        print(logEntry)
    }
    
    func clear() {
        logs.removeAll()
        NotificationCenter.default.post(name: .loggerDidUpdate, object: nil)
    }
    
    var allLogs: String {
        return logs.joined(separator: "\n")
    }
}

extension Notification.Name {
    static let loggerDidUpdate = Notification.Name("loggerDidUpdate")
}
