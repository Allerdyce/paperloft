import Foundation
import Darwin

/// Bounded copies of untrusted provider/source URLs. Every path component is
/// opened relative to a held directory descriptor, without following symlinks.
public enum HandoffFileCopy {
    @discardableResult
    public static func copy(source: URL, destination: URL) throws -> Int64 {
        try copy(source: source, destination: destination, didOpen: nil)
    }

    // A deterministic race seam for tests; production callers cannot supply it.
    static func copy(source: URL, destination: URL, didOpen: (() throws -> Void)?) throws -> Int64 {
        let sourceFD = try SafeFileDescriptor.open(source, flags: O_RDONLY)
        defer { Darwin.close(sourceFD) }
        let before = try SafeFileDescriptor.regularFileStatus(sourceFD)
        guard before.st_size >= 0, before.st_size <= HandoffStore.maximumFileBytes else { throw HandoffError.fileTooLarge }
        let destinationFD = try SafeFileDescriptor.open(destination, flags: O_WRONLY | O_CREAT | O_EXCL)
        defer { Darwin.close(destinationFD) }
        _ = try SafeFileDescriptor.regularFileStatus(destinationFD)
        let reader = FileHandle(fileDescriptor: sourceFD, closeOnDealloc: false)
        let writer = FileHandle(fileDescriptor: destinationFD, closeOnDealloc: false)
        try didOpen?()
        var count: Int64 = 0
        while let chunk = try reader.read(upToCount: 256 * 1_024), !chunk.isEmpty {
            count += Int64(chunk.count)
            guard count <= HandoffStore.maximumFileBytes else { throw HandoffError.fileTooLarge }
            try writer.write(contentsOf: chunk)
        }
        let after = try SafeFileDescriptor.regularFileStatus(sourceFD)
        guard count == before.st_size, before.st_size == after.st_size,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { throw HandoffError.sourceChanged }
        // Also reject a replaced source pathname instead of silently publishing
        // an earlier inode when the provider changes its reference during copy.
        let currentFD = try SafeFileDescriptor.open(source, flags: O_RDONLY)
        defer { Darwin.close(currentFD) }
        let current = try SafeFileDescriptor.regularFileStatus(currentFD)
        guard before.st_dev == current.st_dev, before.st_ino == current.st_ino else { throw HandoffError.sourceChanged }
        try writer.synchronize()
        return count
    }
}

/// Never resolves an attacker-controlled intermediate symlink before opening.
/// O_NONBLOCK prevents a swapped FIFO/device from blocking before fstat rejects it.
enum SafeFileDescriptor {
    static func open(_ url: URL, flags: Int32) throws -> Int32 {
        guard url.isFileURL, !url.path.contains("\0"), !url.pathComponents.contains(".."),
              let filename = url.pathComponents.last, filename != "/", filename != "." else { throw HandoffError.unsafePath }
        // NSItemProvider returns /var/folders URLs on macOS. Normalize only
        // these fixed OS-root aliases; never resolve user-controlled symlinks.
        var path = url.path
        if path.hasPrefix("/var/") || path.hasPrefix("/tmp/") { path = "/private" + path }
        let components = URL(fileURLWithPath: path).pathComponents
        // Search/traversal access is sufficient; selected-file grants do not
        // necessarily authorize listing any ancestor directory.
        var directoryFD = Darwin.open("/", O_EXEC | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0 else { throw posixError() }
        defer { Darwin.close(directoryFD) }
        for component in components.dropFirst().dropLast() {
            let next = Darwin.openat(directoryFD, component, O_EXEC | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw posixError() }
            Darwin.close(directoryFD)
            directoryFD = next
        }
        let result = Darwin.openat(directoryFD, filename, flags | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, mode_t(0o600))
        guard result >= 0 else { throw posixError() }
        return result
    }

    static func regularFileStatus(_ descriptor: Int32) throws -> stat {
        var result = stat()
        guard Darwin.fstat(descriptor, &result) == 0 else { throw posixError() }
        guard (result.st_mode & S_IFMT) == S_IFREG else { throw HandoffError.unsafePath }
        return result
    }

    static func posixError() -> Error {
        if errno == ELOOP || errno == ENOTDIR { return HandoffError.unsafePath }
        return POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
