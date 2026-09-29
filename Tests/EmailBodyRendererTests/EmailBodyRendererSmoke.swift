import AppKit
import Darwin
import Foundation
import PDFKit

private enum Failure: Error { case check(String) }
private func require(_ condition: @autoclosure () -> Bool, _ description: String) throws {
    guard condition() else { throw Failure.check(description) }
}

/// An actual loopback listener: catches requests to malicious test-resource URLs.
/// It never connects to or exposes a listener on any external interface.
private final class LoopbackProbe {
    let descriptor: Int32
    let port: UInt16
    init() throws {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Failure.check("probe socket") }
        self.descriptor = descriptor
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, Darwin.listen(descriptor, 16) == 0 else { Darwin.close(descriptor); throw Failure.check("probe bind") }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        self.port = UInt16(bigEndian: address.sin_port)
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
        // Positive control proves this listener can observe local connections.
        let client = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        defer { Darwin.close(client) }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(client, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard connected == 0 else { Darwin.close(descriptor); throw Failure.check("probe control connection") }
        var readiness = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        guard Darwin.poll(&readiness, 1, 2_000) > 0 else { Darwin.close(descriptor); throw Failure.check("probe control readiness") }
        let accepted = Darwin.accept(descriptor, nil, nil)
        guard accepted >= 0 else { Darwin.close(descriptor); throw Failure.check("probe control observation") }
        Darwin.close(accepted)
    }
    deinit { Darwin.close(descriptor) }
    func connections() -> Int {
        var count = 0
        while true {
            let accepted = Darwin.accept(descriptor, nil, nil)
            if accepted < 0 { return count }
            Darwin.close(accepted); count += 1
        }
    }
}

@main struct EmailBodyRendererSmoke {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let renderer = OfflineEmailBodyRenderer()
        let envelope = EmailBodyRenderRequest.Envelope(from: "Synthetic Shop <orders@example.invalid>", to: "Test Person <person@example.invalid>", date: "2026-09-29", subject: "Receipt 123")
        let simple = try await renderer.render(.init(body: .plainText("Synthetic Shop\nCoffee\nTotal $12.34"), envelope: envelope))
        guard let first = PDFDocument(data: simple.data), let firstText = first.string else { throw Failure.check("readable PDF") }
        for text in ["From:", "orders@example.invalid", "To:", "person@example.invalid", "Date: 2026-09-29", "Subject: Receipt 123", "Total $12.34"] {
            try require(firstText.contains(text), "selectable header/body: " + text)
        }
        try require(first.pageCount == 1 && simple.pageCount == 1, "one-page PDF")
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/email-render/synthetic-email.pdf")
        try simple.data.write(to: output)
        print("PASS selectable text + envelope header, one-page PDF")

        let probe = try LoopbackProbe()
        let url = "http://127.0.0.1:\(probe.port)/must-not-load"
        let hostile = """
        <html><head><base href="\(url)"><meta http-equiv="refresh" content="0;url=\(url)">
        <link rel="stylesheet" href="\(url)"><style>@import url('\(url)');@font-face{font-family:bad;src:url('\(url)')}</style>
        <script>fetch('\(url)');new Image().src='\(url)';window.location='\(url)'</script></head>
        <body onload="fetch('\(url)')"><p>Synthetic HTML receipt</p>
        <img src="\(url)" srcset="\(url) 2x"><iframe src="\(url)">hidden iframe</iframe>
        <svg><image href="\(url)"/></svg><object data="\(url)"></object>
        <video poster="\(url)"><source src="\(url)"></video><input type="image" src="\(url)">
        <form action="\(url)"><button formaction="\(url)">No action</button></form>
        <table><tr><td>Subtotal</td><td>20.00</td></tr><tr><td>Total</td><td>&pound;24.00</td></tr></table>
        <p>&lt;img src=&quot;\(url)&quot;&gt;</p><a href="javascript:fetch('\(url)')">Visible link text</a></body></html>
        """
        let request = EmailBodyRenderRequest(body: .html(hostile), envelope: .init(subject: "</pre><img src='\(url)'>"))
        let prepared = try PreparedEmailBody(request: request, limits: .init())
        for tag in ["<img", "<iframe", "<svg", "<object", "<script", "<link", "<base", "<form", "<video"] {
            try require(!prepared.html.contains(tag), "original resource tag removed: " + tag)
        }
        let result = try await renderer.render(request)
        guard let pdf = PDFDocument(data: result.data), let body = pdf.string else { throw Failure.check("HTML PDF") }
        for text in ["Synthetic HTML receipt", "Subtotal", "20.00", "Total", "£24.00", "Visible link text"] {
            try require(body.contains(text), "HTML visible text: " + text)
        }
        try require(!body.contains("hidden iframe") && !body.contains("new Image"), "hidden code discarded")
        try require(result.blockedNavigationCount == 0, "no external navigation attempted")
        try require(probe.connections() == 0, "zero observed malicious-resource connections")
        print("PASS malicious resources removed; zero observed loopback connections and external navigations")

        let many = (1...95).map { "Receipt line \($0) Total 12.34" }.joined(separator: "\n")
        let paged = try await renderer.render(.init(body: .plainText(many), envelope: envelope))
        guard let document = PDFDocument(data: paged.data) else { throw Failure.check("paged PDF") }
        try require(document.pageCount == 3 && paged.pageCount == 3, "three real paper pages")
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { throw Failure.check("missing page") }
            let bounds = page.bounds(for: .mediaBox)
            try require(abs(bounds.width - 612) < 1 && abs(bounds.height - 792) < 1, "letter paper bounds")
        }
        try require(document.page(at: 2)?.string?.contains("Receipt line 95") == true, "last line not clipped")
        let allText = document.string ?? ""
        for index in 1...95 {
            let phrase = "Receipt line \(index) Total 12.34"
            try require(allText.components(separatedBy: phrase).count == 2, "every line appears exactly once")
        }
        print("PASS three fixed-size pages; all 95 lines selectable exactly once")

        try await expect(.payloadLimit) { _ = try await renderer.render(.init(body: .plainText(String(repeating: "x", count: 256 * 1_024 + 1)))) }
        try await expect(.payloadLimit) { _ = try await renderer.render(.init(body: .plainText("small"), envelope: .init(subject: String(repeating: "x", count: 4_097)))) }
        try await expect(.pageLimit) { _ = try await OfflineEmailBodyRenderer(limits: .init(maximumPages: 1)).render(.init(body: .plainText(many))) }
        try await expect(.payloadLimit) { _ = try await renderer.render(.init(body: .plainText("x" + String(repeating: "\u{0301}", count: 100)))) }
        try await expect(.malformedHTML) { _ = try await renderer.render(.init(body: .html("<script>never closed"))) }
        try await expect(.timedOut) { _ = try await OfflineEmailBodyRenderer(limits: .init(timeout: .milliseconds(1))).render(.init(body: .plainText(many))) }
        let cancellation = Task { try await renderer.render(.init(body: .plainText(many))) }
        await Task.yield(); cancellation.cancel()
        do { _ = try await cancellation.value; throw Failure.check("cancellation must fail") }
        catch is CancellationError {}
        print("PASS payload/header/page limits, malformed HTML, timeout and cancellation")
    }

    @MainActor private static func expect(_ expected: EmailBodyRenderError, operation: () async throws -> Void) async throws {
        do { try await operation(); throw Failure.check("expected \(expected)") }
        catch let error as EmailBodyRenderError { try require(error == expected, "expected \(expected), got \(error)") }
    }
}
