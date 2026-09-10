import AppKit
import Foundation

if CommandLine.arguments.contains("--write-skhdrc") {
    let items = Config.load()
    do {
        try FileManager.default.createDirectory(at: Paths.dir, withIntermediateDirectories: true)
        try Config.save(items)
        try Config.writeSkhdrc(items)
        Config.reloadSkhd()
    } catch {
        fputs("commandk: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

let wantsSettings = CommandLine.arguments.contains("--settings")
let app = NSApplication.shared
let delegate = AppDelegate(wantsSettings: wantsSettings)
app.delegate = delegate
app.setActivationPolicy(wantsSettings ? .regular : .accessory)
app.run()
