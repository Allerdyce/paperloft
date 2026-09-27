import AppKit
import PaperloftKit

/// Receives only an explicitly dropped promise; never enumerates a mailbox.
@MainActor final class MailPromiseReceiver {
    let destination: URL
    let ready: @MainActor (URL) -> Void
    let failed: @MainActor (String) -> Void
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Paperloft email promises"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    init(destination: URL, ready: @escaping @MainActor (URL) -> Void, failed: @escaping @MainActor (String) -> Void) {
        self.destination = destination; self.ready = ready; self.failed = failed
    }
    func accepts(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
    }
    @discardableResult func receive(_ pasteboard: NSPasteboard) -> Bool {
        guard let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver], !receivers.isEmpty else { return false }
        var advertisedFiles = 0
        for receiver in receivers {
            let count = max(1, receiver.fileTypes.count)
            guard count <= 20 - advertisedFiles else { failed("Drop up to 20 email files at a time."); return false }
            advertisedFiles += count
        }
        let budget = PromiseDeliveryBudget()
        do {
            // All receivers in this drag share one new directory, as AppKit requires.
            let folder = destination.appendingPathComponent("Mail-Drop-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: queue) { [receiver] url, error in
                    defer { withExtendedLifetime(receiver) {} }
                    do {
                        if let error { throw error }
                        guard budget.claim() else { throw MailDocument.Failure.limit("20 promised email files per drop") }
                        // Snapshot while AppKit's coordinated reader callback is active.
                        let snapshot = try MailImport.snapshotPromisedEmail(url, in: folder)
                        Task { @MainActor [self] in ready(snapshot) }
                    } catch {
                        let message = "The dropped email could not be imported. " + error.localizedDescription + " Save it as an EML file in Mail, then choose Import. The original email is unchanged."
                        Task { @MainActor [self] in failed(message) }
                    }
                }
            }
            return true
        } catch {
            failed("The dropped email could not be saved. " + error.localizedDescription + " Choose Import for a saved EML file instead.")
            return false
        }
    }
}

/// Legacy promises may advertise one type for several files; enforce the delivery count as well.
private final class PromiseDeliveryBudget: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining = 20
    func claim() -> Bool {
        lock.withLock {
            guard remaining > 0 else { return false }
            remaining -= 1; return true
        }
    }
}
