import Foundation
import IOBluetooth

class BluetoothAutoConnector: NSObject {
    var keyboardMAC: String?
    var trackpadMAC: String?
    
    private var timer: Timer?
    private var wasKeyboardConnected = false
    private var isTrackpadConnected = false
    
    // Polling intervals: fast when waiting for keyboard, slow when both connected
    private let fastInterval: TimeInterval = 2.0
    private let slowInterval: TimeInterval = 30.0
    
    var isMonitoring: Bool {
        return timer != nil
    }
    
    weak var delegate: BluetoothAutoConnectorDelegate?
    
    func startMonitoring() {
        guard let keyboardMAC = keyboardMAC, let trackpadMAC = trackpadMAC else {
            Logger.shared.log("ERROR: Both keyboard and trackpad MAC addresses must be configured")
            return
        }
        
        // Stop any existing timer first
        timer?.invalidate()
        
        wasKeyboardConnected = false
        isTrackpadConnected = false
        timer = Timer.scheduledTimer(withTimeInterval: fastInterval, repeats: true) { [weak self] _ in
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
        
        // Use native IOBluetooth API instead of blueutil
        let normalizedTarget = normalizeMAC(keyboardMAC)
        Logger.shared.log("Looking for keyboard: \(normalizedTarget)")
        
        var isKeyboardConnected = false
        var isTrackpadCurrentlyConnected = false
        let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        
        Logger.shared.log("Found \(pairedDevices.count) paired devices")
        
        for device in pairedDevices {
            let normalizedAddress = normalizeMAC(device.addressString)
            if normalizedAddress == normalizedTarget {
                isKeyboardConnected = device.isConnected()
                Logger.shared.log("Found keyboard: \(device.name ?? "Unknown") - connected: \(isKeyboardConnected)")
            }
            if let trackpadMAC = trackpadMAC, normalizedAddress == normalizeMAC(trackpadMAC) {
                isTrackpadCurrentlyConnected = device.isConnected()
            }
        }
        
        isTrackpadConnected = isTrackpadCurrentlyConnected
        
        // Adjust polling interval: slow down when both are connected
        let shouldUseSlowPolling = isKeyboardConnected && isTrackpadConnected
        let currentInterval = timer?.timeInterval ?? fastInterval
        let targetInterval = shouldUseSlowPolling ? slowInterval : fastInterval
        
        if currentInterval != targetInterval {
            Logger.shared.log("Adjusting polling interval from \(currentInterval)s to \(targetInterval)s")
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: targetInterval, repeats: true) { [weak self] _ in
                self?.checkConnectionStatus()
            }
            RunLoop.current.add(timer!, forMode: .common)
        }
        
        Logger.shared.log("Keyboard connected: \(isKeyboardConnected) (was: \(wasKeyboardConnected)), Trackpad connected: \(isTrackpadConnected)")
        
        if isKeyboardConnected && !wasKeyboardConnected {
            wasKeyboardConnected = true
            Logger.shared.log("EVENT: Keyboard connected - triggering trackpad connection")
            delegate?.keyboardDidConnect()
            connectTrackpad()
        } else if !isKeyboardConnected && wasKeyboardConnected {
            wasKeyboardConnected = false
            Logger.shared.log("EVENT: Keyboard disconnected")
        }
    }
    
    func connectTrackpad() {
        guard let mac = trackpadMAC else {
            Logger.shared.log("ERROR: No trackpad MAC configured")
            return
        }
        
        let normalizedMAC = normalizeMAC(mac)
        Logger.shared.log("Connecting trackpad: \(normalizedMAC)")
        
        // Find the trackpad device and connect using native API
        let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        
        for device in pairedDevices {
            if normalizeMAC(device.addressString) == normalizedMAC {
                Logger.shared.log("Found trackpad: \(device.name ?? "Unknown"), attempting connection...")
                
                // Attempt connection
                let result = device.openConnection()
                
                if result == kIOReturnSuccess {
                    // Verify connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        
                        if device.isConnected() {
                            Logger.shared.log("SUCCESS: Trackpad connected")
                            self.delegate?.trackpadConnectedSuccessfully()
                        } else {
                            Logger.shared.log("FAILED: Trackpad connection attempt completed but not connected")
                            self.delegate?.trackpadConnectionFailed()
                        }
                    }
                } else {
                    Logger.shared.log("FAILED: Could not open connection (error: \(result))")
                    delegate?.trackpadConnectionFailed()
                }
                return
            }
        }
        
        Logger.shared.log("ERROR: Trackpad not found in paired devices")
        delegate?.trackpadConnectionFailed()
    }
    
    private func normalizeMAC(_ mac: String) -> String {
        return mac.lowercased().replacingOccurrences(of: ":", with: "-")
    }
}

protocol BluetoothAutoConnectorDelegate: AnyObject {
    func keyboardDidConnect()
    func trackpadConnectedSuccessfully()
    func trackpadConnectionFailed()
}
