import Foundation
import CoreGraphics
import CoreText
import PDFKit
import Darwin

/// Materializes only a user-selected email into new app-owned files; never changes the email.
public enum MailImport {
    public struct Result: Sendable {
        public let documents: [URL]
        public let notices: [String]
        public let envelope: MailEnvelope?
    }
    public static func materialize(source: URL, destination: URL) throws -> Result {
        let mail = try MailDocument.parse(readBounded(source))
        // Validate all attachments before creating any output. Signature alone is insufficient.
        for pdf in mail.pdfs {
            guard let document = PDFDocument(data: pdf.data), !document.isLocked, document.pageCount > 0,
                  document.pageCount <= 200 else {
                throw MailDocument.Failure.unsupported("a PDF attachment is damaged, locked or exceeds 200 pages; save an unlocked PDF from Mail")
            }
        }
        let body = mail.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let rendered = body.isEmpty ? nil : try bodyPDF(body)
        guard rendered != nil || !mail.pdfs.isEmpty else { throw MailDocument.Failure.unsupported("no readable email body or PDF attachments") }
        let folder = destination.appendingPathComponent("Email-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        var urls: [URL] = []
        if let rendered {
            let url = folder.appendingPathComponent("Email body-" + UUID().uuidString + ".pdf")
            try rendered.write(to: url, options: .withoutOverwriting); urls.append(url)
        }
        for pdf in mail.pdfs {
            // The sender's filename is a display hint only and never becomes a path.
            let url = folder.appendingPathComponent("Attachment-" + UUID().uuidString + ".pdf")
            try pdf.data.write(to: url, options: .withoutOverwriting); urls.append(url)
        }
        return Result(documents: urls, notices: ["Imported from \(source.lastPathComponent). The original email is unchanged. Review each document before filing."] + mail.notices, envelope: mail.envelope)
    }

    public static func readBounded(_ source: URL) throws -> Data {
        guard source.isFileURL else { throw MailDocument.Failure.unsupported("choose an email file on this Mac") }
        let fd = open(source.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw MailDocument.Failure.unsupported("the email is unavailable; import it again to renew access") }
        let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? file.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw MailDocument.Failure.unsupported("choose a regular .eml file") }
        guard info.st_size <= MailDocument.maximumBytes else { throw MailDocument.Failure.limit("50 MB message; save the receipt as a PDF from Mail") }
        var data = Data()
        // The extra byte catches a file growing after fstat without allocating unbounded input.
        while let chunk = try file.read(upToCount: min(65_536, MailDocument.maximumBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= MailDocument.maximumBytes else { throw MailDocument.Failure.limit("50 MB message; save the receipt as a PDF from Mail") }
        }
        return data
    }

    public static func bodyPDF(_ body: String) throws -> Data {
        guard body.utf8.count <= MailDocument.maximumBodyBytes else { throw MailDocument.Failure.limit("1 MB text body") }
        let bytes = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: bytes), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw MailDocument.Failure.unsupported("the email preview could not be created; save a PDF from Mail")
        }
        let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let text = NSAttributedString(string: body, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let setter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: CGRect(x: 48, y: 48, width: 516, height: 696), transform: nil)
        var offset = 0, pages = 0
        while offset < text.length {
            guard pages < 200 else { throw MailDocument.Failure.limit("200 email body pages; save the relevant receipt as a PDF from Mail") }
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { throw MailDocument.Failure.unsupported("the email text could not fit on a page") }
            context.beginPDFPage(nil); CTFrameDraw(frame, context); context.endPDFPage()
            offset += visible.length; pages += 1
        }
        context.closePDF()
        return bytes as Data
    }
}
