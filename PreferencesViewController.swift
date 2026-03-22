import Cocoa
import IOBluetooth

class PreferencesViewController: NSViewController {
    weak var connector: BluetoothAutoConnector!
    
    var keyboardMACField: NSTextField!
    var trackpadMACField: NSTextField!
    var tableView: NSTableView!
    var scrollView: NSScrollView!
    var pairedDevices: [IOBluetoothDevice] = []
    
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
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
        
        // Create table view for paired devices
        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = NSTableHeaderView()
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        // Add columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 250
        nameColumn.minWidth = 150
        nameColumn.maxWidth = 400
        tableView.addTableColumn(nameColumn)

        let addressColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("address"))
        addressColumn.title = "MAC Address"
        addressColumn.width = 140
        addressColumn.minWidth = 120
        addressColumn.maxWidth = 160
        tableView.addTableColumn(addressColumn)

        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 100
        statusColumn.minWidth = 80
        statusColumn.maxWidth = 120
        tableView.addTableColumn(statusColumn)
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = false
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
            scrollView.heightAnchor.constraint(equalToConstant: 100)
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
        
        // Enable copy/paste and selection
        field.isSelectable = true
        field.isEditable = true
        
        // Allow right-click context menu
        field.allowsEditingTextAttributes = false
        
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
            self.tableView.reloadData()
        }
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

extension PreferencesViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return pairedDevices.count
    }
}

extension PreferencesViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < pairedDevices.count, let column = tableColumn else { return nil }
        
        let device = pairedDevices[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
        
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            let textField = NSTextField()
            textField.isEditable = false
            textField.isSelectable = true
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.usesSingleLineMode = true
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(textField)
            cell?.textField = textField
            if let tf = cell?.textField {
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                    tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                    tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }
        }
        
        switch column.identifier.rawValue {
        case "name":
            cell?.textField?.stringValue = device.name ?? "Unknown"
        case "address":
            cell?.textField?.stringValue = device.addressString ?? "Unknown"
        case "status":
            let isConnected = device.isConnected()
            cell?.textField?.stringValue = isConnected ? "Connected" : "Disconnected"
            cell?.textField?.textColor = isConnected ? .systemGreen : .systemRed
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            let row = tableView.selectedRow
            let column = tableView.selectedColumn
            
            guard row >= 0, column >= 0 else { return }
            
            if let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
               let textField = cellView.textField {
                self.view.window?.makeFirstResponder(textField)
            }
        }
    }
}

extension PreferencesViewController {
    @IBAction func copy(_ sender: Any?) {
        guard tableView.clickedRow >= 0 else { return }
        
        let row = tableView.clickedRow
        let column = tableView.clickedColumn
        let device = pairedDevices[row]
        var textToCopy = ""
        
        switch column {
        case 0:
            textToCopy = device.name ?? "Unknown"
        case 1:
            textToCopy = device.addressString ?? "Unknown"
        case 2:
            textToCopy = device.isConnected() ? "Connected" : "Disconnected"
        default:
            break
        }
        
        if !textToCopy.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToCopy, forType: .string)
        }
    }
}
