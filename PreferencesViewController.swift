import Cocoa

class PreferencesViewController: NSViewController {
    weak var connector: BluetoothAutoConnector!
    
    var keyboardMACField: NSTextField!
    var trackpadMACField: NSTextField!
    var infoTextView: NSTextView!
    
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 300))
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    func setupUI() {
        let titleLabel = NSTextField(labelWithString: "Device Sync Configuration")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let keyboardSection = createSectionLabel("Keyboard Bluetooth MAC")
        view.addSubview(keyboardSection)
        
        keyboardMACField = createTextField(placeholder: "XX-XX-XX-XX-XX-XX")
        view.addSubview(keyboardMACField)
        
        let trackpadSection = createSectionLabel("Trackpad Bluetooth MAC")
        view.addSubview(trackpadSection)
        
        trackpadMACField = createTextField(placeholder: "XX-XX-XX-XX-XX-XX")
        view.addSubview(trackpadMACField)
        
        let saveButton = NSButton(title: "Save & Start", target: self, action: #selector(saveSettings))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
        let detectButton = NSButton(title: "Show Paired Devices", target: self, action: #selector(showPairedDevices))
        detectButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detectButton)
        
        infoTextView = NSTextView()
        infoTextView.translatesAutoresizingMaskIntoConstraints = false
        infoTextView.isEditable = false
        infoTextView.font = NSFont.systemFont(ofSize: 11)
        infoTextView.backgroundColor = NSColor.textBackgroundColor
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = infoTextView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            keyboardSection.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            keyboardSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            keyboardMACField.topAnchor.constraint(equalTo: keyboardSection.bottomAnchor, constant: 8),
            keyboardMACField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            keyboardMACField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            trackpadSection.topAnchor.constraint(equalTo: keyboardMACField.bottomAnchor, constant: 20),
            trackpadSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            trackpadMACField.topAnchor.constraint(equalTo: trackpadSection.bottomAnchor, constant: 8),
            trackpadMACField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trackpadMACField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            saveButton.topAnchor.constraint(equalTo: trackpadMACField.bottomAnchor, constant: 20),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            detectButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 12),
            detectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: detectButton.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    func createSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    func createTextField(placeholder: String) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        keyboardMACField.stringValue = defaults.string(forKey: "keyboardMAC") ?? ""
        trackpadMACField.stringValue = defaults.string(forKey: "trackpadMAC") ?? ""
    }
    
    @objc func saveSettings() {
        let keyboardMAC = keyboardMACField.stringValue.trimmingCharacters(in: .whitespaces)
        let trackpadMAC = trackpadMACField.stringValue.trimmingCharacters(in: .whitespaces)
        
        guard !keyboardMAC.isEmpty, !trackpadMAC.isEmpty else {
            showAlert(message: "Please enter both MAC addresses.")
            return
        }
        
        guard isValidMAC(keyboardMAC), isValidMAC(trackpadMAC) else {
            showAlert(message: "Invalid MAC address format. Use format: XX-XX-XX-XX-XX-XX")
            return
        }
        
        let defaults = UserDefaults.standard
        defaults.set(keyboardMAC, forKey: "keyboardMAC")
        defaults.set(trackpadMAC, forKey: "trackpadMAC")
        
        connector.keyboardMAC = keyboardMAC
        connector.trackpadMAC = trackpadMAC
        
        connector.startMonitoring()
        
        showAlert(message: "Settings saved and monitoring started!")
        view.window?.close()
    }
    
    func isValidMAC(_ mac: String) -> Bool {
        let pattern = "^[0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}$"
        return mac.range(of: pattern, options: .regularExpression) != nil
    }
    
    @objc func showPairedDevices() {
        infoTextView.string = "Fetching paired devices..."
        
        // Try first location
        runBlueutil(at: "/opt/homebrew/bin/blueutil") { [weak self] output, error in
            guard let self = self else { return }
            
            if let output = output, !output.isEmpty {
                DispatchQueue.main.async {
                    self.infoTextView.string = output
                }
            } else {
                // Try second location
                self.runBlueutil(at: "/usr/local/bin/blueutil") { [weak self] output2, error2 in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let output2 = output2, !output2.isEmpty {
                            self.infoTextView.string = output2
                        } else {
                            let errorMsg = error2 ?? error ?? "Unknown error"
                            self.infoTextView.string = "Error: Could not run blueutil.\n\nError: \(errorMsg)\n\nInstall with: brew install blueutil"
                        }
                    }
                }
            }
        }
    }
    
    func runBlueutil(at path: String, completion: @escaping (String?, String?) -> Void) {
        let task = Process()
        task.launchPath = path
        task.arguments = ["--paired"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.terminationHandler = { process in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            
            if process.terminationStatus == 0 {
                completion(output, nil)
            } else {
                completion(nil, output ?? "Exit code: \(process.terminationStatus)")
            }
        }
        
        do {
            try task.run()
        } catch {
            completion(nil, error.localizedDescription)
        }
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
