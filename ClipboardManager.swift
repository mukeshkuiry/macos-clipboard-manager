import Cocoa
import Carbon
import ApplicationServices

// MARK: - Models

struct ClipboardItem: Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var timestamp: Date = Date()
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id || lhs.text == rhs.text
    }
}

// MARK: - HotKey Manager

class HotKeyManager {
    static var registeredHotKeys = [UInt32: () -> Void]()
    
    static func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, action: @escaping () -> Void) -> Bool {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(12345), id: id)
        
        registeredHotKeys[id] = action
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }
    
    static func setupHandler() {
        let handler: EventHandlerProcPtr = { (nextHandler, event, userData) -> OSStatus in
            guard let event = event else { return noErr }
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                if let action = HotKeyManager.registeredHotKeys[hotKeyID.id] {
                    DispatchQueue.main.async {
                        action()
                    }
                }
            }
            return noErr
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
    }
}

// MARK: - Custom List Cell View

class ClipboardCellView: NSTableCellView {
    let indexLabel = NSTextField(labelWithString: "")
    let previewLabel = NSTextField(labelWithString: "")
    let countLabel = NSTextField(labelWithString: "")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        indexLabel.textColor = .secondaryLabelColor
        
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        previewLabel.textColor = .labelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        countLabel.textColor = .tertiaryLabelColor
        countLabel.alignment = .right
        
        addSubview(indexLabel)
        addSubview(previewLabel)
        addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            indexLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 28),
            
            previewLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 4),
            previewLabel.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -10),
            previewLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
    }
}

// MARK: - Panel Window Subclass

class PopupPanel: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    @objc func windowDidResignKey(_ notification: Notification) {
        self.orderOut(nil)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 { // Escape
            self.orderOut(nil)
            return true
        }
        
        // Return/Enter to paste selected
        if event.keyCode == 36 {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.pasteSelected()
            }
            return true
        }
        
        // Command + 1..9 Quick Paste
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1 && num <= 9 {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.pasteAtIndex(num - 1)
                }
                return true
            }
        }
        
        // Navigation: Down Arrow
        if event.keyCode == 125 {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                let tableView = appDelegate.tableView
                let currentRow = tableView.selectedRow
                if currentRow < tableView.numberOfRows - 1 {
                    tableView.selectRowIndexes(IndexSet(integer: currentRow + 1), byExtendingSelection: false)
                    tableView.scrollRowToVisible(currentRow + 1)
                }
            }
            return true
        }
        
        // Navigation: Up Arrow
        if event.keyCode == 126 {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                let tableView = appDelegate.tableView
                let currentRow = tableView.selectedRow
                if currentRow > 0 {
                    tableView.selectRowIndexes(IndexSet(integer: currentRow - 1), byExtendingSelection: false)
                    tableView.scrollRowToVisible(currentRow - 1)
                }
            }
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - HUD Window

class HUDWindow: NSWindow {
    let titleLabel = NSTextField(labelWithString: "")
    let previewLabel = NSTextField(labelWithString: "")
    var fadeTimer: Timer?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 14
        visualEffectView.layer?.masksToBounds = true
        self.contentView = visualEffectView
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        previewLabel.textColor = .labelColor
        previewLabel.alignment = .center
        previewLabel.lineBreakMode = .byTruncatingTail
        
        visualEffectView.addSubview(titleLabel)
        visualEffectView.addSubview(previewLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -16),
            
            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            previewLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -16),
            previewLabel.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -12)
        ])
    }
    
    func show(title: String, preview: String) {
        self.titleLabel.stringValue = title
        
        var cleanPreview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if cleanPreview.count > 80 {
            cleanPreview = String(cleanPreview.prefix(80)) + "..."
        }
        self.previewLabel.stringValue = cleanPreview
        
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.origin.x + (screenFrame.size.width - 340) / 2
            let y = screenFrame.origin.y + 40
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        
        self.fadeTimer?.invalidate()
        self.fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self?.animator().alphaValue = 0.0
            } completionHandler: {
                self?.orderOut(nil)
            }
        }
    }
}

// MARK: - Core Application Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    
    var popupWindow: PopupPanel!
    var hudWindow: HUDWindow!
    var statusItem: NSStatusItem?
    
    let searchField = NSSearchField()
    let tableView = NSTableView()
    
    var history = [ClipboardItem]()
    var filteredList = [ClipboardItem]()
    var cycleIndex = -1
    
    var isProgrammaticCopy = false
    var lastChangeCount = NSPasteboard.general.changeCount
    var pollingTimer: Timer?
    
    // Captures the PID of the application active before our popup appeared
    var targetAppPid: pid_t?
    
    let maxHistory = 100
    
    let appFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config")
        .appendingPathComponent("macos-clipboard-manager")
        
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // 1. Create app folder and load database
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
        self.history = loadHistory()
        self.filteredList = history
        
        // 2. Setup interface
        setupPopup()
        setupHUD()
        setupStatusItem()
        
        // 3. Register global hotkeys using Carbon
        HotKeyManager.setupHandler()
        
        // Option + V -> Toggle Popup
        _ = HotKeyManager.register(keyCode: 9, modifiers: translateModifiers(["option"]), id: 1) { [weak self] in
            self?.togglePopup()
        }
        
        // Option + C -> Cycle Clipboard History
        _ = HotKeyManager.register(keyCode: 8, modifiers: translateModifiers(["option"]), id: 2) { [weak self] in
            self?.cycleClipboard()
        }
        
        // 4. Start Clipboard monitor
        startClipboardMonitor()
    }
    
    private func startClipboardMonitor() {
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let pasteboard = NSPasteboard.general
            if pasteboard.changeCount != self.lastChangeCount {
                self.lastChangeCount = pasteboard.changeCount
                self.checkClipboard()
            }
        }
    }
    
    private func checkClipboard() {
        if isProgrammaticCopy { return }
        
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        let newItem = ClipboardItem(id: UUID(), text: text, timestamp: Date())
        
        // Move to top if duplicate
        if let idx = history.firstIndex(of: newItem) {
            history.remove(at: idx)
        }
        history.insert(newItem, at: 0)
        
        if history.count > maxHistory {
            history.removeLast()
        }
        
        saveHistory()
        
        DispatchQueue.main.async { [weak self] in
            self?.filterListItems()
        }
    }
    
    // MARK: - Advanced Paste Workaround (0% Permission Required!)
    
    func paste(item: ClipboardItem) {
        self.isProgrammaticCopy = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        
        popupWindow.orderOut(nil)
        
        let pid = self.targetAppPid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if AXIsProcessTrusted(), let targetPid = pid {
                let source = CGEventSource(stateID: .combinedSessionState)
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v'
                vDown?.flags = .maskCommand
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                vUp?.flags = .maskCommand
                
                vDown?.postToPid(targetPid)
                vUp?.postToPid(targetPid)
                
                self.hudWindow.show(title: "Pasted successfully", preview: item.text)
            } else {
                // If Accessibility is restricted by your organization:
                // The item is already copied, simply show a prompt to press Cmd+V!
                self.hudWindow.show(title: "Copied! Press ⌘V to Paste", preview: item.text)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isProgrammaticCopy = false
            }
        }
    }
    
    func pasteSelected() {
        let row = tableView.selectedRow
        if row >= 0 && row < filteredList.count {
            paste(item: filteredList[row])
        }
    }
    
    func pasteAtIndex(_ index: Int) {
        if index >= 0 && index < filteredList.count {
            paste(item: filteredList[index])
        }
    }
    
    func cycleClipboard() {
        if history.isEmpty { return }
        
        cycleIndex = (cycleIndex + 1) % history.count
        let item = history[cycleIndex]
        
        self.isProgrammaticCopy = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        
        hudWindow.show(
            title: "Clipboard Cycle [\(cycleIndex + 1)/\(history.count)] - Press ⌘V",
            preview: item.text
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProgrammaticCopy = false
        }
    }
    
    @objc func togglePopup() {
        if popupWindow.isVisible {
            popupWindow.orderOut(nil)
        } else {
            // CRITICAL STEP: Grab the active application PID before we focus our popup!
            if let frontmost = NSWorkspace.shared.frontmostApplication,
               frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.targetAppPid = frontmost.processIdentifier
            }
            
            searchField.stringValue = ""
            filterListItems()
            
            if let screen = getActiveScreen() {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.origin.x + (screenFrame.size.width - 500) / 2
                let y = screenFrame.origin.y + (screenFrame.size.height - 320) * 0.7
                popupWindow.setFrame(NSRect(x: x, y: y, width: 500, height: 320), display: true)
            }
            
            popupWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            popupWindow.makeFirstResponder(searchField)
        }
    }
    
    func filterListItems() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            filteredList = history
        } else {
            filteredList = history.filter { $0.text.lowercased().contains(query) }
        }
        
        tableView.reloadData()
        
        if !filteredList.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        
        cycleIndex = -1
    }
    
    @objc func clearHistoryPrompt() {
        let alert = NSAlert()
        alert.messageText = "Clear History?"
        alert.informativeText = "Are you sure you want to clear your clipboard history?"
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        popupWindow.orderOut(nil)
        
        if alert.runModal() == .alertFirstButtonReturn {
            history.removeAll()
            filteredList.removeAll()
            saveHistory()
            tableView.reloadData()
            cycleIndex = -1
            hudWindow.show(title: "History Cleared", preview: "")
        }
    }
    
    // MARK: - Interface Assembly
    
    private func setupPopup() {
        popupWindow = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 320))
        
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 14
        visualEffectView.layer?.masksToBounds = true
        popupWindow.contentView = visualEffectView
        
        searchField.placeholderString = "Search clipboard..."
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.bezelStyle = .roundedBezel
        searchField.isBezeled = true
        searchField.drawsBackground = true
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(searchField)
        
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(separator)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(scrollView)
        
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 34
        tableView.wantsLayer = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(tableViewDoubleClicked)
        if #available(macOS 11.0, *) {
            tableView.style = .inset
        }
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardColumn"))
        column.width = 480
        tableView.addTableColumn(column)
        scrollView.documentView = tableView
        
        let footerLabel = NSTextField(labelWithString: "💡 Press Return to Copy  |  Press ⌘V to Paste  |  Esc to close")
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.alignment = .center
        visualEffectView.addSubview(footerLabel)
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 24),
            
            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 2),
            scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -2),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -4),
            
            footerLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 14),
            footerLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -14),
            footerLabel.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -8),
            footerLabel.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    private func setupHUD() {
        hudWindow = HUDWindow()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "📋"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Clipboard Manager Active", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open History (⌥V)", action: #selector(togglePopup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistoryPrompt), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func tableViewDoubleClicked() {
        pasteSelected()
    }
    
    func getActiveScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    }
    
    // MARK: - NSTableView Delegate & DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredList.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipboardCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? ClipboardCellView
        
        if cell == nil {
            cell = ClipboardCellView()
            cell?.identifier = identifier
        }
        
        let item = filteredList[row]
        cell?.indexLabel.stringValue = row < 9 ? "⌘\(row + 1)" : ""
        cell?.previewLabel.stringValue = item.text.replacingOccurrences(of: "\n", with: " ")
        cell?.countLabel.stringValue = "\(item.text.count) chars"
        
        return cell
    }
    
    // MARK: - Search Field Delegate
    
    func controlTextDidChange(_ obj: Notification) {
        filterListItems()
    }
    
    // MARK: - Data Storage
    
    private func loadHistory() -> [ClipboardItem] {
        let fileURL = appFolder.appendingPathComponent("database.json")
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            return []
        }
    }
    
    private func saveHistory() {
        let fileURL = appFolder.appendingPathComponent("database.json")
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: fileURL)
        }
    }
    
    private func translateModifiers(_ list: [String]) -> UInt32 {
        var mods: UInt32 = 0
        for mod in list {
            switch mod.lowercased() {
            case "cmd", "command": mods |= UInt32(cmdKey)
            case "shift": mods |= UInt32(shiftKey)
            case "option", "alt": mods |= UInt32(optionKey)
            case "ctrl", "control": mods |= UInt32(controlKey)
            default: break
            }
        }
        return mods
    }
}

// MARK: - Main Executable

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
