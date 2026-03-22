import Foundation
import IOBluetooth

class BluetoothAutoConnector: NSObject {
    var keyboardMAC: String?
    var trackpadMAC: String?
    
    private var timer: Timer?
    private var wasKeyboardConnected = false
    private var isTrackpadConnected = false
    
    private let pollingInterval: TimeInterval = 2.0
    
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
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
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
        
        Logger.shared.log("Keyboard connected: \(isKeyboardConnected) (was: \(wasKeyboardConnected)), Trackpad connected: \(isTrackpadConnected)")
        
        if isKeyboardConnected && !wasKeyboardConnected {
            wasKeyboardConnected = true
            Logger.shared.log("EVENT: Keyboard connected - triggering trackpad connection")
            delegate?.keyboardDidConnect()
            connectTrackpad()
        } else if !isKeyboardConnected && wasKeyboardConnected {
            wasKeyboardConnected = false
            Logger.shared.log("EVENT: Keyboard disconnected - triggering trackpad disconnection")
            delegate?.keyboardDidDisconnect()
            disconnectTrackpad()
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
                
                // Check if already connected
                if device.isConnected() {
                    Logger.shared.log("Trackpad already connected")
                    delegate?.trackpadConnectedSuccessfully()
                    return
                }
                
                // Attempt connection with retry
                attemptConnection(to: device, retryCount: 3)
                return
            }
        }
        
        Logger.shared.log("ERROR: Trackpad not found in paired devices")
        delegate?.trackpadConnectionFailed()
    }
    
    func disconnectTrackpad() {
        guard let mac = trackpadMAC else {
            Logger.shared.log("ERROR: No trackpad MAC configured")
            return
        }
        
        let normalizedMAC = normalizeMAC(mac)
        Logger.shared.log("Disconnecting trackpad: \(normalizedMAC)")
        
        // Find the trackpad device and disconnect using native API
        let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        
        for device in pairedDevices {
            if normalizeMAC(device.addressString) == normalizedMAC {
                Logger.shared.log("Found trackpad: \(device.name ?? "Unknown"), disconnecting...")
                
                // Check if already disconnected
                if !device.isConnected() {
                    Logger.shared.log("Trackpad already disconnected")
                    delegate?.trackpadDisconnectedSuccessfully()
                    return
                }
                
                // Disconnect the device
                let result = device.closeConnection()
                
                if result == kIOReturnSuccess {
                    Logger.shared.log("SUCCESS: Trackpad disconnected")
                    delegate?.trackpadDisconnectedSuccessfully()
                } else {
                    Logger.shared.log("FAILED: Could not disconnect trackpad (error: \(result))")
                    delegate?.trackpadDisconnectionFailed()
                }
                return
            }
        }
        
        Logger.shared.log("ERROR: Trackpad not found in paired devices")
        delegate?.trackpadDisconnectionFailed()
    }
    
    private func attemptConnection(to device: IOBluetoothDevice, retryCount: Int) {
        guard retryCount > 0 else {
            Logger.shared.log("FAILED: Exhausted all connection retries")
            delegate?.trackpadConnectionFailed()
            return
        }
        
        Logger.shared.log("Connection attempt \(4 - retryCount)/3...")
        let result = device.openConnection()
        
        if result == kIOReturnSuccess {
            // Verify connection after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                
                if device.isConnected() {
                    Logger.shared.log("SUCCESS: Trackpad connected")
                    self.delegate?.trackpadConnectedSuccessfully()
                } else {
                    Logger.shared.log("Connection pending, retrying...")
                    self.attemptConnection(to: device, retryCount: retryCount - 1)
                }
            }
        } else if result == -536870186 {
            // kIOReturnNotPermitted - device busy or not ready
            Logger.shared.log("Device busy (error: \(result)), will retry in 2s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.attemptConnection(to: device, retryCount: retryCount - 1)
            }
        } else {
            Logger.shared.log("FAILED: Could not open connection (error: \(result))")
            delegate?.trackpadConnectionFailed()
        }
    }
    
    private func normalizeMAC(_ mac: String) -> String {
        return mac.lowercased().replacingOccurrences(of: ":", with: "-")
    }
}

protocol BluetoothAutoConnectorDelegate: AnyObject {
    func keyboardDidConnect()
    func keyboardDidDisconnect()
    func trackpadConnectedSuccessfully()
    func trackpadConnectionFailed()
    func trackpadDisconnectedSuccessfully()
    func trackpadDisconnectionFailed()
}
