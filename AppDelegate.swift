import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var connector: BluetoothAutoConnector!
    var preferencesWindow: NSWindow?
    var logsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("App launching...")
        
        // Setup main menu with Edit menu for copy/paste
        setupMainMenu()
        
        connector = BluetoothAutoConnector()
        connector.delegate = self
        
        setupMenuBar()
        loadSettings()
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        Logger.shared.log("Settings loaded - keyboard MAC: \(connector.keyboardMAC ?? "not set"), trackpad MAC: \(connector.trackpadMAC ?? "not set")")
        
        if connector.keyboardMAC != nil && connector.trackpadMAC != nil {
            Logger.shared.log("Auto-starting monitoring...")
            connector.startMonitoring()
            updateMenuStatus(isRunning: true)
        } else {
            Logger.shared.log("Please configure devices in Preferences to start monitoring")
            updateMenuStatus(isRunning: false)
        }
        
        Logger.shared.log("App started successfully")
    }
    
    func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit menu for copy/paste
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Device Sync")
        }
        
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "Status: Stopped", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let startStopItem = NSMenuItem(title: "Start Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "s")
        startStopItem.tag = 101
        menu.addItem(startStopItem)
        
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Logs...", action: #selector(showLogs), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        self.statusItem.menu = menu
    }
    
    @objc func toggleMonitoring() {
        if connector.keyboardMAC == nil {
            showAlert(message: "Please configure your devices in Preferences.")
            return
        }
        
        if connector.isMonitoring {
            connector.stopMonitoring()
            updateMenuStatus(isRunning: false)
            Logger.shared.log("Monitoring stopped")
        } else {
            connector.startMonitoring()
            updateMenuStatus(isRunning: true)
            Logger.shared.log("Monitoring started")
        }
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let vc = PreferencesViewController()
            vc.connector = connector
            
            let window = NSWindow(contentViewController: vc)
            window.title = "Device Sync Preferences"
            window.styleMask = [.titled, .closable]
            window.center()
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showLogs() {
        if logsWindow == nil {
            let vc = LogsViewController()
            
            let window = NSWindow(contentViewController: vc)
            window.title = "Logs"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 400))
            window.center()
            logsWindow = window
        }
        
        logsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        connector.keyboardMAC = defaults.string(forKey: "keyboardMAC")
        connector.trackpadMAC = defaults.string(forKey: "trackpadMAC")
    }
    
    func updateMenuStatus(isRunning: Bool? = nil) {
        guard let menu = statusItem.menu else { return }
        
        let running = isRunning ?? connector.isMonitoring
        
        if let statusItem = menu.item(withTag: 100) {
            let title = running ? "Status: Running" : "Status: Stopped"
            let color = running ? NSColor.systemGreen : NSColor.systemRed
            
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: color
            ]
            statusItem.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        }
        
        if let startStopItem = menu.item(withTag: 101) {
            startStopItem.title = running ? "Stop Monitoring" : "Start Monitoring"
        }
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

extension AppDelegate: BluetoothAutoConnectorDelegate {
    func keyboardDidConnect() {
        DispatchQueue.main.async {
            Logger.shared.log("Keyboard connected - attempting trackpad connection")
            self.showNotification(title: "Keyboard Connected", body: "Attempting to connect trackpad...")
        }
    }
    
    func keyboardDidDisconnect() {
        DispatchQueue.main.async {
            Logger.shared.log("Keyboard disconnected - attempting trackpad disconnection")
            self.showNotification(title: "Keyboard Disconnected", body: "Disconnecting trackpad...")
        }
    }
    
    func trackpadConnectedSuccessfully() {
        DispatchQueue.main.async {
            Logger.shared.log("Trackpad connected successfully")
            self.showNotification(title: "Trackpad Connected", body: "Successfully connected to trackpad!")
        }
    }
    
    func trackpadConnectionFailed() {
        DispatchQueue.main.async {
            Logger.shared.log("Trackpad connection failed")
            self.showNotification(title: "Connection Failed", body: "Could not connect to trackpad.")
        }
    }
    
    func trackpadDisconnectedSuccessfully() {
        DispatchQueue.main.async {
            Logger.shared.log("Trackpad disconnected successfully")
            self.showNotification(title: "Trackpad Disconnected", body: "Successfully disconnected trackpad!")
        }
    }
    
    func trackpadDisconnectionFailed() {
        DispatchQueue.main.async {
            Logger.shared.log("Trackpad disconnection failed")
            self.showNotification(title: "Disconnection Failed", body: "Could not disconnect trackpad.")
        }
    }
    
    func showNotification(title: String, body: String) {
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = body
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notification, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
