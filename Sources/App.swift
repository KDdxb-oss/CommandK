import AppKit

struct Scored {
    let item: CommandItem
    let score: Double
    let matchedAlias: String?
}

final class KeyWindow: NSWindow {
    var keyHandler: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let keyHandler, keyHandler(event) { return }
        super.sendEvent(event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    let panel = KeyWindow(
        contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    let launchedAt = Date()
    let search = NSTextField(string: "")
    let table = NSTableView()
    let scroll = NSScrollView()
    let placeholder = NSTextField(labelWithString: "Type a command")
    var commands: [CommandItem] = []
    var shown: [Scored] = []
    var selected = 0
    var keyMonitor: Any?
    var settingsWindow: NSWindow?
    var settingsTable: NSTableView?
    var recordingIndex: Int?
    var settingsOpen = false
    let wantsSettings: Bool

    init(wantsSettings: Bool) {
        self.wantsSettings = wantsSettings
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        commands = Config.load()
        if wantsSettings {
            openSettings()
        } else {
            shown = allScored()
            buildPalette()
            filter("")
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(search)
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) == true ? nil : event
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        if settingsOpen { return }
        if Date().timeIntervalSince(launchedAt) < 0.6 { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            if self.settingsOpen { return }
            if !self.panel.isKeyWindow { NSApp.terminate(nil) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            NSApp.terminate(nil)
        }
    }

    // MARK: Palette

    func allScored() -> [Scored] {
        commands
            .map { Scored(item: $0, score: $0.rank, matchedAlias: nil) }
            .sorted {
                if $0.score == $1.score { return $0.item.title < $1.item.title }
                return $0.score > $1.score
            }
    }

    func buildPalette() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.title = "CommandK"
        panel.animationBehavior = .utilityWindow

        let chrome = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 560))
        chrome.wantsLayer = true
        chrome.layer?.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 0.97).cgColor
        chrome.layer?.cornerRadius = 14
        chrome.layer?.borderWidth = 1
        chrome.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        chrome.autoresizingMask = [.width, .height]
        panel.contentView = chrome

        search.isBordered = false
        search.drawsBackground = false
        search.focusRingType = .none
        search.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        search.textColor = .white
        search.placeholderString = ""
        search.delegate = self
        search.cell?.sendsActionOnEndEditing = false
        search.frame = NSRect(x: 20, y: 512, width: 500, height: 32)
        search.autoresizingMask = [.width, .minYMargin]
        search.isEditable = true
        search.isSelectable = true
        chrome.addSubview(search)

        placeholder.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        placeholder.textColor = NSColor.white.withAlphaComponent(0.28)
        placeholder.frame = search.frame
        placeholder.autoresizingMask = search.autoresizingMask
        chrome.addSubview(placeholder, positioned: .below, relativeTo: search)

        let gear = NSButton(frame: NSRect(x: 530, y: 512, width: 28, height: 28))
        gear.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gear.imagePosition = .imageOnly
        gear.isBordered = false
        gear.bezelStyle = .shadowlessSquare
        gear.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        gear.target = self
        gear.action = #selector(openSettings)
        gear.autoresizingMask = [.minXMargin, .minYMargin]
        chrome.addSubview(gear)

        let rule = NSView(frame: NSRect(x: 0, y: 500, width: 580, height: 1))
        rule.wantsLayer = true
        rule.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        rule.autoresizingMask = [.width, .minYMargin]
        chrome.addSubview(rule)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cmd"))
        col.width = 580
        table.addTableColumn(col)
        table.headerView = nil
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.rowHeight = 40
        table.intercellSpacing = .zero
        table.allowsEmptySelection = false
        table.focusRingType = .none
        table.target = self
        table.action = #selector(clickedPaletteRow)
        table.doubleAction = #selector(runSelected)

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = false
        scroll.scrollerStyle = .legacy
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.frame = NSRect(x: 0, y: 8, width: 580, height: 492)
        scroll.autoresizingMask = [.width, .height]
        chrome.addSubview(scroll)

        panel.keyHandler = { [weak self] event in
            self?.handleKey(event) ?? false
        }
        positionPanel()
    }

    func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let vis = screen.visibleFrame
        let size = NSSize(width: 580, height: 560)
        let origin = NSPoint(
            x: vis.midX - size.width / 2,
            y: vis.midY - size.height / 2 + 20
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    func handleKey(_ event: NSEvent) -> Bool {
        if let idx = recordingIndex {
            if event.keyCode == 53 {
                recordingIndex = nil
                settingsTable?.reloadData()
                return true
            }
            let bind = Keys.bind(from: event)
            if Keys.isReserved(bind) { NSSound.beep(); return true }
            commands[idx].bind = bind
            recordingIndex = nil
            persist()
            settingsTable?.reloadData()
            return true
        }
        if settingsOpen { return false }
        switch event.keyCode {
        case 125: moveSel(1); return true
        case 126: moveSel(-1); return true
        case 36, 76: runSelected(); return true
        case 53: NSApp.terminate(nil); return true
        default:
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "k" {
                NSApp.terminate(nil); return true
            }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
                openSettings(); return true
            }
            return false
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)) { moveSel(1); return true }
        if commandSelector == #selector(NSResponder.moveUp(_:)) { moveSel(-1); return true }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { runSelected(); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { NSApp.terminate(nil); return true }
        if commandSelector == #selector(NSResponder.scrollToEndOfDocument(_:)) { moveSel(shown.count); return true }
        if commandSelector == #selector(NSResponder.scrollToBeginningOfDocument(_:)) { selected = 0; refreshSelection(); return true }
        if commandSelector == #selector(NSResponder.pageDown(_:)) { moveSel(8); return true }
        if commandSelector == #selector(NSResponder.pageUp(_:)) { moveSel(-8); return true }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        let q = search.stringValue
        placeholder.isHidden = !q.isEmpty
        filter(q)
    }

    func moveSel(_ delta: Int) {
        guard !shown.isEmpty else { return }
        selected = max(0, min(shown.count - 1, selected + delta))
        refreshSelection()
    }

    func refreshSelection() {
        table.reloadData()
        table.scrollRowToVisible(selected)
    }

    @objc func clickedPaletteRow() {
        let row = table.clickedRow
        guard row >= 0 else { return }
        selected = row
        refreshSelection()
    }

    @objc func runSelected() {
        guard shown.indices.contains(selected) else { return }
        let item = shown[selected].item
        if item.command == "__settings__" {
            openSettings()
            return
        }
        panel.orderOut(nil)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", item.command]
        try? task.run()
        NSApp.terminate(nil)
    }

    func filter(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            shown = allScored()
        } else {
            shown = commands.compactMap { item -> Scored? in
                var best = fuzzy(item.title, q)
                var alias: String?
                for a in item.aliases {
                    let s = fuzzy(a, q)
                    if s > best { best = s; alias = a }
                }
                best = max(best, fuzzy(item.bind, q), fuzzy(Keys.label(item.bind), q))
                guard best > 0.001 else { return nil }
                return Scored(item: item, score: best * max(item.rank, 0.15), matchedAlias: alias)
            }
            .sorted { $0.score > $1.score }
        }
        selected = 0
        table.reloadData()
        if !shown.isEmpty { table.scrollRowToVisible(0) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === settingsTable { return commands.count }
        return shown.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === settingsTable {
            return settingsRow(column: tableColumn?.identifier.rawValue ?? "", row: row)
        }
        return paletteRow(row)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView === settingsTable { return true }
        selected = row
        table.reloadData()
        return true
    }

    func paletteRow(_ row: Int) -> NSView {
        let scored = shown[row]
        let item = scored.item
        let rowView = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 40))
        if row == selected {
            let bg = NSView(frame: NSRect(x: 8, y: 2, width: 564, height: 36))
            bg.wantsLayer = true
            bg.layer?.backgroundColor = NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.72, alpha: 0.55).cgColor
            bg.layer?.cornerRadius = 8
            rowView.addSubview(bg)
        }
        if let image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
            let icon = NSImageView(image: image)
            icon.contentTintColor = .white
            icon.frame = NSRect(x: 20, y: 10, width: 18, height: 18)
            rowView.addSubview(icon)
        }
        var titleText = item.title
        if let alias = scored.matchedAlias { titleText += "  (\(alias))" }
        let title = NSTextField(labelWithString: titleText)
        title.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        title.textColor = .white
        title.frame = NSRect(x: 46, y: 11, width: 360, height: 18)
        rowView.addSubview(title)
        let keys = Keys.label(item.bind)
        if !keys.isEmpty {
            let lab = NSTextField(labelWithString: keys)
            lab.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            lab.textColor = NSColor.white.withAlphaComponent(0.55)
            lab.alignment = .right
            lab.frame = NSRect(x: 400, y: 11, width: 150, height: 18)
            rowView.addSubview(lab)
        }
        return rowView
    }

    // MARK: Settings

    @objc func openSettings() {
        settingsOpen = true
        panel.hidesOnDeactivate = false
        panel.orderOut(nil)
        if settingsWindow == nil { buildSettings() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func buildSettings() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "CommandK Settings"
        win.delegate = self
        win.center()
        win.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 640))
        win.contentView = content

        let hint = NSTextField(labelWithString: "Click a shortcut, then press the new keys. Esc cancels. ⌘K always opens CommandK.")
        hint.font = NSFont.systemFont(ofSize: 12)
        hint.textColor = NSColor.white.withAlphaComponent(0.55)
        hint.frame = NSRect(x: 20, y: 608, width: 680, height: 20)
        hint.autoresizingMask = [.width, .minYMargin]
        content.addSubview(hint)

        let tv = NSTableView()
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Action"
        nameCol.width = 360
        let bindCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bind"))
        bindCol.title = "Shortcut"
        bindCol.width = 200
        let recCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("record"))
        recCol.title = ""
        recCol.width = 110
        tv.addTableColumn(nameCol)
        tv.addTableColumn(bindCol)
        tv.addTableColumn(recCol)
        tv.rowHeight = 32
        tv.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1)
        tv.headerView?.wantsLayer = true
        tv.target = self
        tv.action = #selector(clickedSettingsRow)
        settingsTable = tv
        tv.delegate = self
        tv.dataSource = self
        tv.reloadData()

        let sv = NSScrollView(frame: NSRect(x: 16, y: 56, width: 688, height: 544))
        sv.documentView = tv
        sv.hasVerticalScroller = true
        sv.autoresizingMask = [.width, .height]
        sv.borderType = .lineBorder
        content.addSubview(sv)

        let save = NSButton(title: "Save shortcuts", target: self, action: #selector(saveSettings))
        save.bezelStyle = .rounded
        save.frame = NSRect(x: 560, y: 16, width: 144, height: 28)
        save.autoresizingMask = [.minXMargin, .maxYMargin]
        content.addSubview(save)

        let clear = NSButton(title: "Clear shortcut", target: self, action: #selector(clearShortcut))
        clear.bezelStyle = .rounded
        clear.frame = NSRect(x: 16, y: 16, width: 130, height: 28)
        clear.autoresizingMask = [.maxYMargin]
        content.addSubview(clear)

        settingsWindow = win
    }

    func settingsRow(column: String, row: Int) -> NSView {
        let item = commands[row]
        if column == "name" {
            let wrap = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 32))
            if let image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
                let icon = NSImageView(image: image)
                icon.contentTintColor = .white
                icon.frame = NSRect(x: 6, y: 7, width: 16, height: 16)
                wrap.addSubview(icon)
            }
            let lab = NSTextField(labelWithString: item.title)
            lab.font = NSFont.systemFont(ofSize: 13)
            lab.textColor = .white
            lab.frame = NSRect(x: 28, y: 6, width: 320, height: 18)
            wrap.addSubview(lab)
            return wrap
        }
        if column == "bind" {
            let text: String
            if recordingIndex == row {
                text = "Press keys…"
            } else {
                let lab = Keys.label(item.bind)
                text = lab.isEmpty ? "None" : lab
            }
            let lab = NSTextField(labelWithString: text)
            lab.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            lab.textColor = recordingIndex == row
                ? NSColor(calibratedRed: 0.75, green: 0.62, blue: 1, alpha: 1)
                : .white
            lab.alignment = .left
            return lab
        }
        let btn = NSButton(title: recordingIndex == row ? "Listening" : "Change", target: self, action: #selector(recordClicked(_:)))
        btn.bezelStyle = .rounded
        btn.tag = row
        return btn
    }

    @objc func clickedSettingsRow() {
        guard let tv = settingsTable else { return }
        if tv.clickedColumn == 1, tv.clickedRow >= 0 {
            recordingIndex = tv.clickedRow
            tv.reloadData()
        }
    }

    @objc func recordClicked(_ sender: NSButton) {
        recordingIndex = sender.tag
        settingsTable?.reloadData()
    }

    @objc func clearShortcut() {
        guard let row = settingsTable?.selectedRow, row >= 0 else { return }
        commands[row].bind = ""
        persist()
        settingsTable?.reloadData()
    }

    @objc func saveSettings() {
        persist()
        NSApp.terminate(nil)
    }

    func persist() {
        do {
            try Config.save(commands)
            try Config.writeSkhdrc(commands)
            Config.reloadSkhd()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not save shortcuts"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

func fuzzy(_ text: String, _ query: String) -> Double {
    let t = Array(text.lowercased())
    let q = Array(query.lowercased())
    if q.isEmpty { return 0 }
    let tl = String(t)
    let ql = String(q)
    if tl == ql { return 1 }
    if tl.hasPrefix(ql) { return 0.92 }
    if tl.contains(ql) { return 0.72 }
    var ti = 0
    var consecutive = 0.0
    var score = 0.0
    for qc in q {
        var found = false
        while ti < t.count {
            if t[ti] == qc {
                score += 1 + consecutive
                consecutive += 0.6
                found = true
                ti += 1
                break
            } else {
                consecutive = 0
                ti += 1
            }
        }
        if !found { return 0 }
    }
    return min(0.68, score / Double(t.count + q.count))
}

