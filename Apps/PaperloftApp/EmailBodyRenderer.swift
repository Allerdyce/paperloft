import AppKit
import CoreGraphics
import CoreText
import Foundation
import PDFKit
import WebKit

struct EmailBodyRenderRequest: Sendable {
    enum Body: Sendable { case plainText(String), html(String) }
    struct Envelope: Sendable {
        let from: String
        let to: String
        let date: String
        let subject: String
        init(from: String = "", to: String = "", date: String = "", subject: String = "") {
            self.from = from; self.to = to; self.date = date; self.subject = subject
        }
    }
    let body: Body
    let envelope: Envelope
    init(body: Body, envelope: Envelope = .init()) { self.body = body; self.envelope = envelope }
}

struct EmailBodyPDF: Sendable {
    enum Engine: String, Sendable { case webKit, nativeText }
    /// Receipt text excludes transport headers, which are source hints only.
    let bodyText: String
    let engine: Engine
    let fallbackDiagnosticCode: Int?
    let data: Data
    let pageCount: Int
    /// Observed navigation requests rejected by the deny-by-default delegate.
    /// This is not a system-wide network monitor. Resource-bearing input markup
    /// never enters WebKit; CSP and the blocking rule list provide further defense.
    let blockedNavigationCount: Int
    init(bodyText: String, data: Data, pageCount: Int, blockedNavigationCount: Int,
         engine: Engine = .webKit, fallbackDiagnosticCode: Int? = nil) {
        self.bodyText = bodyText; self.data = data; self.pageCount = pageCount
        self.blockedNavigationCount = blockedNavigationCount; self.engine = engine
        self.fallbackDiagnosticCode = fallbackDiagnosticCode
    }
}

@MainActor protocol EmailBodyRendering {
    func render(_ request: EmailBodyRenderRequest) async throws -> EmailBodyPDF
}

enum EmailBodyRenderError: Error, LocalizedError, CustomNSError, Equatable {
    case payloadLimit, pageLimit, outputLimit, malformedHTML, unavailable, timedOut, invalidPDF
    case ruleListUnavailable, webContentTerminated

    static let errorDomain = "app.paperloft.email-renderer"
    var errorCode: Int {
        switch self {
        case .payloadLimit: 1
        case .pageLimit: 2
        case .outputLimit: 3
        case .malformedHTML: 4
        case .unavailable: 5
        case .timedOut: 6
        case .invalidPDF: 7
        case .ruleListUnavailable: 1001
        case .webContentTerminated: 1002
        }
    }
    var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? "Email rendering failed."] }
    var errorDescription: String? {
        switch self {
        case .payloadLimit: "This email body is too large to render safely."
        case .pageLimit: "This email body exceeds the PDF page limit."
        case .outputLimit: "The rendered email PDF exceeds the safe size limit."
        case .malformedHTML: "The email contains malformed HTML."
        case .unavailable, .ruleListUnavailable, .webContentTerminated: "The offline email renderer is unavailable."
        case .timedOut: "Rendering the email took too long. Please try again."
        case .invalidPDF: "The email could not be rendered as a readable PDF."
        }
    }
}

@MainActor final class OfflineEmailBodyRenderer: EmailBodyRendering {
    struct Limits: Sendable {
        let maximumBodyBytes: Int
        let maximumPages: Int
        let timeout: Duration
        init(maximumBodyBytes: Int = 256 * 1_024, maximumPages: Int = 40, timeout: Duration = .seconds(15)) {
            self.maximumBodyBytes = min(max(maximumBodyBytes, 1), 256 * 1_024)
            self.maximumPages = min(max(maximumPages, 1), 40)
            self.timeout = min(max(timeout, .milliseconds(1)), .seconds(30))
        }
    }
    enum Policy { case automatic, webKitOnly, nativeOnly }
    private let limits: Limits
    private let policy: Policy
    // A failed WebKit startup is not retried for every receipt in this process.
    // No sandbox or network permission is relaxed to make WebKit start.
    private static var unavailableWebKitCode: Int?
    init(limits: Limits = .init(), policy: Policy = .automatic) { self.limits = limits; self.policy = policy }

    func render(_ request: EmailBodyRenderRequest) async throws -> EmailBodyPDF {
        try Task.checkCancellation()
        let prepared = try PreparedEmailBody(request: request, limits: limits)
        if policy == .nativeOnly || (policy == .automatic && Self.unavailableWebKitCode != nil) {
            return try await renderNative(prepared, diagnostic: policy == .automatic ? Self.unavailableWebKitCode : nil)
        }
        let job = EmailRenderJob(prepared: prepared, timeout: limits.timeout)
        do {
            return try await withTaskCancellationHandler {
                try await job.run()
            } onCancel: {
                Task { @MainActor in job.cancel() }
            }
        } catch let error as EmailBodyRenderError where policy == .automatic && (error == .ruleListUnavailable || error == .webContentTerminated) {
            try Task.checkCancellation()
            Self.unavailableWebKitCode = error.errorCode
            return try await renderNative(prepared, diagnostic: error.errorCode)
        }
    }

    /// This path never instantiates WebKit or parses HTML. It draws only already
    /// sanitized, bounded, pre-wrapped text with native CoreText into real PDF pages.
    private func renderNative(_ prepared: PreparedEmailBody, diagnostic: Int?) async throws -> EmailBodyPDF {
        let deadline = ContinuousClock.now.advanced(by: limits.timeout)
        let bytes = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: PreparedEmailBody.width, height: PreparedEmailBody.height)
        guard let consumer = CGDataConsumer(data: bytes),
              let context = CGContext(consumer: consumer, mediaBox: &box,
                                      [kCGPDFContextCreator: "Paperloft Receipts"] as CFDictionary) else {
            throw EmailBodyRenderError.invalidPDF
        }
        var closed = false
        defer { if !closed { context.closePDF() } }
        let font = CTFontCreateWithName("Menlo" as CFString, 12, nil)
        for page in prepared.pages {
            await Task.yield()
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw EmailBodyRenderError.timedOut }
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(box)
            context.setFillColor(CGColor(gray: 0.067, alpha: 1))
            context.textMatrix = .identity
            for (index, line) in page.components(separatedBy: "\n").enumerated() {
                let attributed = NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                context.textPosition = CGPoint(x: 48, y: PreparedEmailBody.height - 60 - CGFloat(index) * 18)
                CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
            }
            context.endPDFPage()
            guard bytes.length <= 32 * 1_024 * 1_024 else { throw EmailBodyRenderError.outputLimit }
        }
        context.closePDF(); closed = true
        try Task.checkCancellation()
        guard ContinuousClock.now < deadline else { throw EmailBodyRenderError.timedOut }
        guard bytes.length <= 32 * 1_024 * 1_024 else { throw EmailBodyRenderError.outputLimit }
        let data = bytes as Data
        guard let document = PDFDocument(data: data), document.pageCount == prepared.pages.count else { throw EmailBodyRenderError.invalidPDF }
        return EmailBodyPDF(bodyText: prepared.bodyText, data: data, pageCount: document.pageCount,
                            blockedNavigationCount: 0, engine: .nativeText, fallbackDiagnosticCode: diagnostic)
    }
}

/// Native preparation deliberately reduces HTML to visible text. Only this fixed
/// template and escaped strings enter WebKit: no original tag, attribute, CSS,
/// URL, script, image or attachment is passed to a browser parser as markup.
@MainActor struct PreparedEmailBody {
    static let width: CGFloat = 612
    static let height: CGFloat = 792
    let pages: [String]
    let bodyText: String
    var html: String {
        let content = pages.map { "<section><pre>" + Self.escape($0) + "</pre></section>" }.joined()
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-src 'none'; sandbox">
        <style>html,body{margin:0;padding:0;background:white;color:#111}section{box-sizing:border-box;width:612px;height:792px;padding:48px;overflow:hidden}pre{margin:0;font-family:Menlo,monospace;font-size:12px;line-height:18px;white-space:pre;tab-size:4}</style>
        </head><body>\(content)</body></html>
        """
    }

    init(request: EmailBodyRenderRequest, limits: OfflineEmailBodyRenderer.Limits) throws {
        let input: String
        switch request.body { case .plainText(let text), .html(let text): input = text }
        guard input.utf8.count <= limits.maximumBodyBytes else { throw EmailBodyRenderError.payloadLimit }
        let envelope = request.envelope
        guard [envelope.from, envelope.to, envelope.date, envelope.subject].allSatisfy({ $0.utf8.count <= 4_096 }) else {
            throw EmailBodyRenderError.payloadLimit
        }
        let body: String
        switch request.body {
        case .plainText(let text): body = text
        case .html(let html): body = try OfflineHTMLText.extract(html)
        }
        bodyText = body
        let fields = ["From: " + envelope.from, "To: " + envelope.to, "Date: " + envelope.date, "Subject: " + envelope.subject]
        // A header field cannot forge additional fields by injecting newlines.
        let header = fields.map { $0.components(separatedBy: .newlines).joined(separator: " ") }.joined(separator: "\n")
        let font = NSFont(name: "Menlo", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        var widths: [Character: CGFloat] = [:], lines: [String] = [], line = "", lineWidth: CGFloat = 0
        func appendLine() throws {
            lines.append(line); line = ""; lineWidth = 0
            guard lines.count <= limits.maximumPages * 38 else { throw EmailBodyRenderError.pageLimit }
        }
        for character in header + "\n\n" + body {
            guard character.unicodeScalars.count <= 64 else { throw EmailBodyRenderError.payloadLimit }
            if character.isNewline { try appendLine(); continue }
            let piece = character == "\t" ? "    " : String(character)
            // Ignore control characters (except the handled line break/tab).
            if piece.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) { continue }
            let width = widths[character] ?? (piece as NSString).size(withAttributes: [.font: font]).width
            widths[character] = width
            if lineWidth + width > 504, !line.isEmpty { try appendLine() }
            line += piece; lineWidth += width
        }
        try appendLine()
        pages = stride(from: 0, to: lines.count, by: 38).map { start in
            lines[start..<min(start + 38, lines.count)].joined(separator: "\n")
        }
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private enum OfflineHTMLText {
    static func extract(_ html: String) throws -> String {
        let chars = Array(html)
        var position = 0, text = "", hidden: [String] = []
        let suppress: Set<String> = ["script", "style", "head", "template", "iframe", "object", "svg", "math", "noscript"]
        let breaks: Set<String> = ["p", "div", "br", "tr", "li", "h1", "h2", "h3", "h4", "hr", "table", "section"]
        while position < chars.count {
            if let raw = hidden.last, raw == "script" || raw == "style" {
                let end = position + raw.count + 2
                if end >= chars.count || String(chars[position..<end]).lowercased() != "</" + raw {
                    position += 1; continue
                }
            }
            if chars[position] == "<" {
                if position + 3 < chars.count, String(chars[position...position + 3]) == "<!--" {
                    position += 4
                    while position + 2 < chars.count, String(chars[position...position + 2]) != "-->" { position += 1 }
                    guard position + 2 < chars.count else { throw EmailBodyRenderError.malformedHTML }
                    position += 3; continue
                }
                position += 1
                var tag = "", quote: Character?
                while position < chars.count {
                    let char = chars[position]
                    if let current = quote { if char == current { quote = nil } }
                    else if char == "\"" || char == "'" { quote = char }
                    else if char == ">" { break }
                    tag.append(char); position += 1
                }
                guard position < chars.count else { throw EmailBodyRenderError.malformedHTML }
                position += 1
                let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let closing = normalized.hasPrefix("/")
                let name = String(normalized.drop(while: { $0 == "/" }).prefix(while: { $0.isLetter || $0.isNumber }))
                if closing, hidden.last == name { hidden.removeLast() }
                else if !closing, suppress.contains(name), !normalized.hasSuffix("/") {
                    guard hidden.count < 32 else { throw EmailBodyRenderError.malformedHTML }
                    hidden.append(name)
                } else if hidden.isEmpty {
                    if breaks.contains(name) { text += "\n" }
                    else if name == "td" || name == "th" { text += "  " }
                }
                continue
            }
            if hidden.isEmpty {
                if chars[position] == "&", let end = chars[(position + 1)...].prefix(16).firstIndex(of: ";"),
                   let decoded = decode(String(chars[(position + 1)..<end])) {
                    text += decoded; position = end + 1; continue
                }
                text.append(chars[position])
            }
            position += 1
        }
        guard hidden.isEmpty else { throw EmailBodyRenderError.malformedHTML }
        return text.split(whereSeparator: \.isNewline).map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func decode(_ entity: String) -> String? {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "pound": "£", "euro": "€", "cent": "¢", "yen": "¥", "copy": "©", "ndash": "–", "mdash": "—", "bull": "•"]
        if let value = named[entity] { return value }
        guard entity.hasPrefix("#") else { return nil }
        let hex = entity.lowercased().hasPrefix("#x")
        guard let value = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10),
              value >= 32, let scalar = UnicodeScalar(value) else { return nil }
        return String(scalar)
    }
}

@MainActor private final class EmailRenderJob: NSObject, WKNavigationDelegate {
    private let prepared: PreparedEmailBody
    private let timeout: Duration
    private var continuation: CheckedContinuation<EmailBodyPDF, any Error>?
    private var webView: WKWebView?
    private var timer: Task<Void, Never>?
    private var pdfTask: Task<Void, Never>?
    private var blocked = 0
    private var startedPDF = false
    private var acceptedInitialNavigation = false
    private let maximumPDFBytes = 32 * 1_024 * 1_024

    init(prepared: PreparedEmailBody, timeout: Duration) { self.prepared = prepared; self.timeout = timeout }

    func run() async throws -> EmailBodyPDF {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            timer = Task { [weak self] in
                do { try await Task.sleep(for: self?.timeout ?? .seconds(15)) } catch { return }
                self?.finish(.failure(EmailBodyRenderError.timedOut))
            }
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "PaperloftOfflineEmail-v1", encodedContentRuleList: """
                [{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]
                """) { [weak self] rule, _ in
                guard let self, self.continuation != nil else { return }
                guard let rule else { self.finish(.failure(EmailBodyRenderError.ruleListUnavailable)); return }
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .nonPersistent()
                configuration.defaultWebpagePreferences.allowsContentJavaScript = false
                configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
                configuration.mediaTypesRequiringUserActionForPlayback = .all
                configuration.userContentController.add(rule)
                let view = WKWebView(frame: NSRect(x: 0, y: 0, width: PreparedEmailBody.width, height: PreparedEmailBody.height), configuration: configuration)
                view.navigationDelegate = self
                self.webView = view
                view.loadHTMLString(self.prepared.html, baseURL: nil)
            }
        }
    }

    func cancel() { finish(.failure(CancellationError())) }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if !acceptedInitialNavigation, action.request.url?.absoluteString == "about:blank", action.targetFrame?.isMainFrame == true {
            acceptedInitialNavigation = true; decisionHandler(.allow)
        } else { blocked += 1; decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { finish(.failure(error)) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(EmailBodyRenderError.webContentTerminated)) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !startedPDF, continuation != nil else { return }
        startedPDF = true
        pdfTask = Task { [weak self] in
            guard let self else { return }
            do {
                let document = PDFDocument()
                var bytes = 0
                for index in self.prepared.pages.indices {
                    try Task.checkCancellation()
                    let configuration = WKPDFConfiguration()
                    configuration.rect = CGRect(x: 0, y: CGFloat(index) * PreparedEmailBody.height, width: PreparedEmailBody.width, height: PreparedEmailBody.height)
                    let data = try await webView.pdf(configuration: configuration)
                    bytes += data.count
                    guard bytes <= self.maximumPDFBytes else { throw EmailBodyRenderError.outputLimit }
                    guard let pageDocument = PDFDocument(data: data), pageDocument.pageCount == 1, let page = pageDocument.page(at: 0) else {
                        throw EmailBodyRenderError.invalidPDF
                    }
                    document.insert(page, at: document.pageCount)
                }
                guard let data = document.dataRepresentation(), data.count <= self.maximumPDFBytes else { throw EmailBodyRenderError.outputLimit }
                self.finish(.success(EmailBodyPDF(bodyText: self.prepared.bodyText, data: data, pageCount: document.pageCount, blockedNavigationCount: self.blocked)))
            } catch { self.finish(.failure(error)) }
        }
    }

    private func finish(_ result: Result<EmailBodyPDF, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timer?.cancel(); timer = nil
        pdfTask?.cancel(); pdfTask = nil
        webView?.stopLoading(); webView?.navigationDelegate = nil; webView = nil
        continuation.resume(with: result)
    }
}
