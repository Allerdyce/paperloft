import Foundation
import PaperloftKit

struct EmailDiagnosticCandidate: Codable {
    let source: String
    let attachmentIndex: Int?
    let selected: Bool
    let contentHash: String?
    let fields: ExtractedFields?
    let error: String?
}

/// Completion and failure accounting only; never an accuracy or gate verdict.
struct EmailDiagnosticStatus: Codable {
    private(set) var completedMessages = 0
    private(set) var processingErrorMessages = 0
    private(set) var classificationFailureMessages = 0
    private(set) var classificationFailureCandidates = 0
    private(set) var sourceChangedMessages = 0
    private(set) var failedMessages = 0
    var exitCode: Int32 { failedMessages == 0 ? 0 : 1 }

    mutating func record(candidates: [EmailDiagnosticCandidate], error: String?, sourcePreserved: Bool) {
        completedMessages += 1
        let processingFailed = error != nil || candidates.contains { $0.error != nil }
        let classificationFailures = candidates.filter { $0.fields?.classificationError != nil }.count
        if processingFailed { processingErrorMessages += 1 }
        if classificationFailures > 0 { classificationFailureMessages += 1 }
        classificationFailureCandidates += classificationFailures
        if !sourcePreserved { sourceChangedMessages += 1 }
        if processingFailed || classificationFailures > 0 || !sourcePreserved { failedMessages += 1 }
    }
}
