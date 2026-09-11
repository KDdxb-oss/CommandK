import AppKit

enum Keys {
    static func bind(from event: NSEvent) -> String {
        var mods: [String] = []
        let f = event.modifierFlags
        if f.contains(.shift) { mods.append("shift") }
        if f.contains(.control) { mods.append("ctrl") }
        if f.contains(.option) { mods.append("alt") }
        if f.contains(.command) { mods.append("cmd") }
        let key = literal(event)
        if mods.isEmpty { return key }
        return mods.joined(separator: " + ") + " - " + key
    }

    static func label(_ bind: String) -> String {
        if bind.isEmpty { return "" }
        let parts = bind.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let key = parts.last else { return bind }
        var out = ""
        let head = parts.dropLast().joined(separator: " ")
        if head.contains("ctrl") { out += "⌃" }
        if head.contains("alt") { out += "⌥" }
        if head.contains("shift") { out += "⇧" }
        if head.contains("cmd") { out += "⌘" }
        out += glyph(String(key))
        return out
    }

    static func literal(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 0x24, 0x4C: return "return"
        case 0x30: return "tab"
        case 0x31: return "space"
        case 0x33: return "backspace"
        case 0x35: return "escape"
        case 0x7B: return "left"
        case 0x7C: return "right"
        case 0x7D: return "down"
        case 0x7E: return "up"
        case 0x75: return "delete"
        case 0x1B: return "0x1B"
        case 0x18: return "0x18"
        case 0x2C: return "0x2C"
        case 0x32: return "0x32"
        default:
            if let c = event.charactersIgnoringModifiers?.lowercased(),
               c.count == 1,
               let ch = c.first,
               ch.isLetter || ch.isNumber {
                return String(ch)
            }
            return String(format: "0x%02X", event.keyCode)
        }
    }

    static func glyph(_ key: String) -> String {
        switch key {
        case "return": return "↩"
        case "tab": return "⇥"
        case "space": return "Space"
        case "backspace": return "⌫"
        case "escape": return "⎋"
        case "left": return "←"
        case "right": return "→"
        case "down": return "↓"
        case "up": return "↑"
        case "delete": return "⌦"
        case "0x1B": return "-"
        case "0x18": return "="
        case "0x2C": return "/"
        case "0x32": return "`"
        case "0x2B": return "<"
        case "0x2F": return ">"
        case "0x27": return "'"
        case "0x29": return ":"
        default: return key.uppercased()
        }
    }

    static func isReserved(_ bind: String) -> Bool {
        let n = bind.replacingOccurrences(of: " ", with: "")
        return n == "cmd-k" || n == "cmd-c" || n == "cmd-v" || n == "cmd-tab" || n == "cmd-space"
    }
}
