import AppKit

if let bundleIdentifier = Bundle.main.bundleIdentifier {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    let currentPID = ProcessInfo.processInfo.processIdentifier

    if running.contains(where: { $0.processIdentifier != currentPID }) {
        NSApp.terminate(nil)
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
