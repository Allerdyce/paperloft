import Foundation
import Darwin

/// An exclusive cross-process consumer lock. Keep this token alive across the
/// entire recovery/claim/intake/acknowledge batch; deallocation releases it.
/// Never unlink .consumer.lock: its stable inode coordinates every consumer.
public final class HandoffConsumerLease: @unchecked Sendable {
    // Immutable ownership: only deinit touches the descriptor after acquisition.
    private let descriptor: Int32
    private init(descriptor: Int32) { self.descriptor = descriptor }

    static func acquire(at url: URL) throws -> HandoffConsumerLease? {
        let descriptor = try SafeFileDescriptor.open(url, flags: O_RDWR | O_CREAT)
        var acquired = false
        defer { if !acquired { Darwin.close(descriptor) } }
        let status = try SafeFileDescriptor.regularFileStatus(descriptor)
        guard status.st_nlink == 1 else { throw HandoffError.unsafePath }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK || errno == EAGAIN { return nil }
            throw SafeFileDescriptor.posixError()
        }
        acquired = true
        return HandoffConsumerLease(descriptor: descriptor)
    }

    deinit {
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }
}
