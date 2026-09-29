import Testing
@testable import PaperloftKit

struct MailCandidateSelectionTests {
    @Test func receiptAttachmentAlwaysSuppressesBodyAcrossMixedSelections() {
        for body in [false, true] {
            let selected = MailCandidateSelection.select([.other, .receipt, .unresolved, .receipt], hasBody: body)
            #expect(selected.attachmentIndices == [1, 2, 3])
            #expect(!selected.includeBody)
        }
    }
    @Test func nonReceiptAttachmentsFallBackToOneBodyAndUnresolvedFilesStayVisible() {
        let newsletter = MailCandidateSelection.select([.other, .other, .other], hasBody: true)
        #expect(newsletter.attachmentIndices.isEmpty)
        #expect(newsletter.includeBody)
        let uncertain = MailCandidateSelection.select([.other, .unresolved], hasBody: true)
        #expect(uncertain.attachmentIndices == [1])
        #expect(uncertain.includeBody)
    }
    @Test func attachmentOnlyNonReceiptEmailProducesOneItem() {
        let selected = MailCandidateSelection.select([.other, .other], hasBody: false)
        #expect(selected.attachmentIndices == [0])
        #expect(!selected.includeBody)
        #expect(MailCandidateSelection.select([], hasBody: false).attachmentIndices.isEmpty)
    }
}
