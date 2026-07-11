import Cocoa

// Avoid stacking up duplicate menu bar icons if launched more than once.
let bundleID = Bundle.main.bundleIdentifier
let currentPID = ProcessInfo.processInfo.processIdentifier
let duplicateRunning = NSWorkspace.shared.runningApplications.contains {
    $0.bundleIdentifier == bundleID && $0.processIdentifier != currentPID
}
if bundleID != nil && duplicateRunning {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon, no app switcher entry
app.run()
