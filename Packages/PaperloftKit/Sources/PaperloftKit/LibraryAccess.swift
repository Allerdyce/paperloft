import Foundation

public enum LibraryAccessError: Error, LocalizedError, Sendable {
    case staleBookmark, unavailable
    public var errorDescription: String? {
        switch self {
        case .staleBookmark: "The library folder permission needs to be renewed. Choose the library folder again."
        case .unavailable: "The library folder is unavailable or permission was revoked. Choose the folder again."
        }
    }
}

/// Immutable lifetime token for a user-granted folder. No automatic permission UI.
public final class LibraryAccess: @unchecked Sendable {
    public let url: URL
    public static func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    public init(bookmark: Data) throws {
        var stale = false
        let resolved: URL
        do {
            resolved = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        } catch { throw LibraryAccessError.unavailable }
        guard !stale else { throw LibraryAccessError.staleBookmark }
        guard resolved.startAccessingSecurityScopedResource() else { throw LibraryAccessError.unavailable }
        do {
            guard try resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw LibraryAccessError.unavailable }
        } catch { resolved.stopAccessingSecurityScopedResource(); throw LibraryAccessError.unavailable }
        url = resolved
    }
    deinit { url.stopAccessingSecurityScopedResource() }
}
