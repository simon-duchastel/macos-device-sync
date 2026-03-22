import Foundation

class BluetoothAutoConnector: NSObject {
    var keyboardMAC: String?
    var trackpadMAC: String?
    
    private var timer: Timer?
    private var wasKeyboardConnected = false
    
    weak var delegate: BluetoothAutoConnectorDelegate?
    
    func startMonitoring() {
        guard let keyboardMAC = keyboardMAC, let trackpadMAC = trackpadMAC else {
            Logger.shared.log("ERROR: Both keyboard and trackpad MAC addresses must be configured")
            return
        }
        
        // Stop any existing timer first
        timer?.invalidate()
        
        wasKeyboardConnected = false
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnectionStatus()
        }
        
        // Ensure timer fires even during scroll/mouse tracking
        RunLoop.current.add(timer!, forMode: .common)
        
        Logger.shared.log("Monitoring started - keyboard: \(keyboardMAC), trackpad: \(trackpadMAC)")
        checkConnectionStatus()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        Logger.shared.log("Monitoring stopped")
    }
    
    func checkConnectionStatus() {
        guard let keyboardMAC = keyboardMAC else {
            Logger.shared.log("ERROR: No keyboard MAC configured")
            return
        }
        
        Logger.shared.log("Checking connection status...")
        
        runBlueutil(args: ["--paired"]) { [weak self] output in
            guard let self = self else { return }
            
            guard let output = output else {
                Logger.shared.log("ERROR: Failed to get paired devices from blueutil")
                return
            }
            
            Logger.shared.log("Got paired devices list (\(output.count) chars)")
            
            let normalizedTarget = keyboardMAC.lowercased().replacingOccurrences(of: ":", with: "-")
            Logger.shared.log("Looking for keyboard: \(normalizedTarget)")
            
            // Parse individual device entries - devices are separated by newlines
            let deviceEntries = output.components(separatedBy: "\n")
            var isConnected = false
            
            for entry in deviceEntries {
                let normalizedEntry = entry.lowercased()
                // Check if this entry contains the target MAC address
                if normalizedEntry.contains("address: \(normalizedTarget)") {
                    // Check if this specific device entry indicates it's connected
                    // Format: "connected (master, 0 dBm)" or "not connected"
                    isConnected = normalizedEntry.contains("connected (")
                    Logger.shared.log("Found keyboard entry: \(entry)")
                    Logger.shared.log("Keyboard connected: \(isConnected)")
                    break
                }
            }
            
            Logger.shared.log("Keyboard connected: \(isConnected) (was: \(self.wasKeyboardConnected))")
            
            if isConnected && !self.wasKeyboardConnected {
                self.wasKeyboardConnected = true
                Logger.shared.log("EVENT: Keyboard connected - triggering trackpad connection")
                self.delegate?.keyboardDidConnect()
                self.connectTrackpad()
            } else if !isConnected && self.wasKeyboardConnected {
                self.wasKeyboardConnected = false
                Logger.shared.log("EVENT: Keyboard disconnected")
            }
        }
    }
    
    func connectTrackpad() {
        guard let mac = trackpadMAC else {
            Logger.shared.log("ERROR: No trackpad MAC configured")
            return
        }
        
        let normalizedMAC = mac.replacingOccurrences(of: ":", with: "-")
        Logger.shared.log("Connecting trackpad: \(normalizedMAC)")
        
        runBlueutil(args: ["--connect", normalizedMAC]) { [weak self] output in
            guard let self = self else { return }
            
            if let output = output {
                Logger.shared.log("blueutil connect output: \(output)")
            } else {
                Logger.shared.log("ERROR: No output from blueutil connect")
            }
            
            self.runBlueutil(args: ["--paired"]) { output in
                guard let output = output else {
                    Logger.shared.log("ERROR: Failed to verify trackpad connection")
                    self.delegate?.trackpadConnectionFailed()
                    return
                }
                
                let normalizedMAC = mac.lowercased().replacingOccurrences(of: ":", with: "-")
                
                // Parse individual device entries
                let deviceEntries = output.components(separatedBy: "\n")
                var isConnected = false
                
                for entry in deviceEntries {
                    let normalizedEntry = entry.lowercased()
                    if normalizedEntry.contains("address: \(normalizedMAC)") {
                        // Format: "connected (master, 0 dBm)" or "not connected"
                        isConnected = normalizedEntry.contains("connected (")
                        Logger.shared.log("Found trackpad entry: \(entry)")
                        Logger.shared.log("Trackpad connected: \(isConnected)")
                        break
                    }
                }
                
                if isConnected {
                    Logger.shared.log("SUCCESS: Trackpad connected")
                    self.delegate?.trackpadConnectedSuccessfully()
                } else {
                    Logger.shared.log("FAILED: Trackpad not in connected state")
                    self.delegate?.trackpadConnectionFailed()
                }
            }
        }
    }
    
    func runBlueutil(args: [String], completion: @escaping (String?) -> Void) {
        let task = Process()
        task.launchPath = "/opt/homebrew/bin/blueutil"
        task.arguments = args
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        Logger.shared.log("Running: blueutil \(args.joined(separator: " "))")
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            Logger.shared.log("blueutil exit code: \(task.terminationStatus)")
            completion(output)
        } catch {
            Logger.shared.log("blueutil not found at /opt/homebrew/bin, trying /usr/local/bin")
            
            let task2 = Process()
            task2.launchPath = "/usr/local/bin/blueutil"
            task2.arguments = args
            
            let pipe2 = Pipe()
            task2.standardOutput = pipe2
            task2.standardError = pipe2
            
            do {
                try task2.run()
                task2.waitUntilExit()
                
                let data = pipe2.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                Logger.shared.log("blueutil (/usr/local) exit code: \(task2.terminationStatus)")
                completion(output)
            } catch {
                Logger.shared.log("ERROR: blueutil not found. Install with: brew install blueutil")
                completion(nil)
            }
        }
    }
}

protocol BluetoothAutoConnectorDelegate: AnyObject {
    func keyboardDidConnect()
    func trackpadConnectedSuccessfully()
    func trackpadConnectionFailed()
}
