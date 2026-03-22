import Cocoa

class LogsViewController: NSViewController {
    var textView: NSTextView!
    
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Add initial placeholder if no logs
        if Logger.shared.allLogs.isEmpty {
            textView.string = "No logs yet. Start monitoring to see activity here."
        } else {
            updateLogs()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLogs),
            name: .loggerDidUpdate,
            object: nil
        )
    }
    
    func setupUI() {
        // Add button first
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearLogs))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clearButton)
        
        // Setup scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)
        
        // Setup text view with proper frame
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView
        
        NSLayoutConstraint.activate([
            clearButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            clearButton.widthAnchor.constraint(equalToConstant: 80),
            
            scrollView.topAnchor.constraint(equalTo: clearButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }
    
    @objc func updateLogs() {
        textView?.string = Logger.shared.allLogs
        if textView?.enclosingScrollView != nil {
            textView?.scrollToEndOfDocument(nil)
        }
    }
    
    @objc func clearLogs() {
        Logger.shared.clear()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
