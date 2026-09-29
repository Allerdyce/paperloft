import Foundation

/// Chooses documents after each attachment has been read once. Unreadable or
/// unclassified attachments remain visible for review rather than being discarded.
public enum MailCandidateSelection {
    public enum Disposition: Sendable, Equatable { case receipt, other, unresolved }
    public struct Selection: Sendable, Equatable {
        public let attachmentIndices: [Int]
        public let includeBody: Bool
    }
    public static func select(_ attachments: [Disposition], hasBody: Bool) -> Selection {
        let receipts = attachments.indices.filter { attachments[$0] == .receipt }
        let unresolved = attachments.indices.filter { attachments[$0] == .unresolved }
        if !receipts.isEmpty {
            return Selection(attachmentIndices: attachments.indices.filter { attachments[$0] != .other }, includeBody: false)
        }
        if hasBody { return Selection(attachmentIndices: unresolved, includeBody: true) }
        // With no body, retain one non-receipt document so the email still has
        // a reviewable result, plus any attachments whose classification failed.
        return Selection(attachmentIndices: unresolved.isEmpty ? Array(attachments.indices.prefix(1)) : unresolved, includeBody: false)
    }
}
