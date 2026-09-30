import AppKit
import CoreGraphics

/// Synthetic share host for local diagnostics only: invokes the Paperloft share extension through
/// NSSharingService from a plain app window, so presentation can be compared with Finder.
/// Arguments: <file> <log> [timeoutSeconds]. It never reads extension or app containers.
@MainActor final class ShareHostProbe: NSObject, NSApplicationDelegate, NSSharingServiceDelegate, @MainActor NSSharingServicePickerDelegate {
    private let file: URL
    private let log: URL
    private let timeout: Double
    private let start = Date()
    private var window: NSWindow?
    private let button = NSButton(title: "Share", target: nil, action: nil)
    private var picker: NSSharingServicePicker?
    private var service: NSSharingService?

    init(file: URL, log: URL, timeout: Double) {
        self.file = file; self.log = log; self.timeout = timeout
    }

    private func write(_ line: String) { Self.append(line, to: log, start: start) }

    nonisolated static func append(_ line: String, to log: URL, start: Date) {
        let text = String(format: "%7.2fs ", Date().timeIntervalSince(start)) + line + "\n"
        FileHandle.standardOutput.write(Data(text.utf8))
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile(); handle.write(Data(text.utf8)); try? handle.close()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Paperloft Share Host Probe"
        button.frame = NSRect(x: 20, y: 20, width: 100, height: 32)
        window.contentView?.addSubview(button)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
        write("launched pid=\(getpid()) file=\(file.lastPathComponent) exists=\(FileManager.default.fileExists(atPath: file.path))")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.showPicker()
        }
        // A sheet's modal run loop does not drain main-actor work, so monitoring and the
        // timeout run on their own thread.
        let log = self.log, start = self.start, timeout = self.timeout
        Thread.detachNewThread {
            var last = ""
            while Date().timeIntervalSince(start) < timeout {
                let state = Self.windowState()
                if state != last { last = state; Self.append("windows: " + state, to: log, start: start) }
                Thread.sleep(forTimeInterval: 0.5)
            }
            Self.append("timeout after \(Int(timeout))s without a completion callback", to: log, start: start)
            Self.append("windows: " + Self.windowState(), to: log, start: start)
            exit(2)
        }
    }

    private func showPicker() {
        let picker = NSSharingServicePicker(items: [file])
        picker.delegate = self
        self.picker = picker
        picker.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        write("picker shown")
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any],
                              proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        write("proposed services: " + proposedServices.map(\.title).joined(separator: " | "))
        if service == nil, let paperloft = proposedServices.first(where: { $0.title.localizedCaseInsensitiveContains("Paperloft") }) {
            service = paperloft
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                self.picker?.close()
                self.perform(paperloft)
            }
        } else if service == nil {
            write("no Paperloft service proposed")
        }
        return proposedServices
    }

    private func perform(_ service: NSSharingService) {
        service.delegate = self
        write("perform title=\(service.title) canPerform=\(service.canPerform(withItems: [file]))")
        service.perform(withItems: [file])
        write("perform returned")
    }

    func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any],
                        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        write("delegate: sourceWindow requested")
        return window
    }
    func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) { write("delegate: willShareItems count=\(items.count)") }
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish("delegate: didShareItems count=\(items.count)", code: 0) }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let error = error as NSError
        finish("delegate: didFailToShareItems domain=\(error.domain) code=\(error.code) \(error.localizedDescription)", code: 1)
    }

    /// Other processes' Paperloft-owned windows (owner, pid, onscreen, size); logged when it changes.
    nonisolated static func windowState() -> String {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let own = Int(getpid())
        let rows = list.compactMap { info -> String? in
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let pid = info[kCGWindowOwnerPID as String] as? Int ?? -1
            guard pid != own, owner.localizedCaseInsensitiveContains("paperloft") else { return nil }
            let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
            let onscreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
            let width = Int(bounds["Width"] ?? 0), height = Int(bounds["Height"] ?? 0)
            guard width > 40, height > 40 else { return nil }
            return "\(owner)[\(pid)] onscreen=\(onscreen) \(width)x\(height)"
        }.sorted().joined(separator: "; ")
        return rows.isEmpty ? "none" : rows
    }

    private func finish(_ line: String, code: Int32) {
        write(line)
        write("windows: " + Self.windowState())
        write("exit \(code)")
        exit(code)
    }
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: ShareHostProbe <file> <log> [timeoutSeconds]\n".utf8))
    exit(64)
}
let application = NSApplication.shared
let probe = ShareHostProbe(file: URL(fileURLWithPath: arguments[1]), log: URL(fileURLWithPath: arguments[2]),
                           timeout: arguments.count > 3 ? Double(arguments[3]) ?? 120 : 120)
application.delegate = probe
application.setActivationPolicy(.regular)
application.run()
