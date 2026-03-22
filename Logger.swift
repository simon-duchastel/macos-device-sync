import Foundation

struct LogEntry {
    let timestamp: Date
    let message: String
    
    var formattedString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .medium
        return "[\(dateFormatter.string(from: timestamp))] \(message)"
    }
}

class Logger {
    static let shared = Logger()
    private var logEntries: [LogEntry] = []
    private let maxLogs = 1000
    private let logFileURL: URL?
    private var autoClearTimer: Timer?
    private let purgeAge: TimeInterval = 300 // 5 minutes
    private var hasPurgedOldLogs = false
    
    var autoClearEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "autoClearLogs") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "autoClearLogs")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoClearLogs")
            if newValue {
                startAutoClearTimer()
            } else {
                stopAutoClearTimer()
            }
        }
    }
    
    private init() {
        // Setup file logging
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("MacOsDeviceSync", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            logFileURL = dir.appendingPathComponent("debug.log")
        } else {
            logFileURL = nil
        }
        
        log("Logger initialized")
        
        // Start auto-clear timer if enabled (default on)
        if autoClearEnabled {
            startAutoClearTimer()
        }
    }
    
    func log(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        let logString = entry.formattedString
        
        // Always write to file first
        if let url = logFileURL {
            let fileEntry = logString + "\n"
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    _ = handle.seekToEndOfFile()
                    handle.write(fileEntry.data(using: .utf8)!)
                    try? handle.close()
                }
            } else {
                try? fileEntry.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        
        // Then update in-memory logs
        DispatchQueue.main.async { [weak self] in
            self?.logEntries.append(entry)
            if let count = self?.logEntries.count, count > self?.maxLogs ?? 1000 {
                self?.logEntries.removeFirst(count - (self?.maxLogs ?? 1000))
                self?.hasPurgedOldLogs = true
            }
            NotificationCenter.default.post(name: .loggerDidUpdate, object: nil)
        }
        
        print(logString)
    }
    
    func clear() {
        logEntries.removeAll()
        hasPurgedOldLogs = false
        NotificationCenter.default.post(name: .loggerDidUpdate, object: nil)
        log("Logs cleared")
    }
    
    func getLogs() -> (logs: [LogEntry], hasPurgedOldLogs: Bool) {
        purgeOldLogs()
        return (logEntries, hasPurgedOldLogs)
    }
    
    var allLogs: String {
        let (entries, purged) = getLogs()
        var result = entries.map { $0.formattedString }.joined(separator: "\n")
        if purged && !entries.isEmpty {
            result = "[Older logs deleted]\n" + result
        }
        return result
    }
    
    var allLogsFromFile: String {
        guard let url = logFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func purgeOldLogs() {
        let cutoffDate = Date().addingTimeInterval(-purgeAge)
        let originalCount = logEntries.count
        logEntries.removeAll { $0.timestamp < cutoffDate }
        if logEntries.count < originalCount {
            hasPurgedOldLogs = true
        }
    }
    
    private func startAutoClearTimer() {
        stopAutoClearTimer()
        // Check every 30 seconds for old logs to purge
        autoClearTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let beforeCount = self.logEntries.count
            self.purgeOldLogs()
            if self.logEntries.count < beforeCount {
                NotificationCenter.default.post(name: .loggerDidUpdate, object: nil)
            }
        }
        if let timer = autoClearTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopAutoClearTimer() {
        autoClearTimer?.invalidate()
        autoClearTimer = nil
    }
}

extension Notification.Name {
    static let loggerDidUpdate = Notification.Name("loggerDidUpdate")
}
