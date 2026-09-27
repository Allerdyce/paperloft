import AppKit
import XCTest
import PaperloftKit

private final class SyntheticEmailPromise: NSObject, NSFilePromiseProviderDelegate {
    let data = Data("Content-Type: text/plain\r\n\r\nVendor: Promise Store\r\nTotal: 12.50".utf8)
    @MainActor func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String { "receipt.eml" }
    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping ((any Error)?) -> Void) {
        do { try data.write(to: url, options: .withoutOverwriting); completionHandler(nil) }
        catch { completionHandler(error) }
    }
}

final class MailPromiseTests: XCTestCase {
    @MainActor func testNativePromisePasteboardIsRecognizedWithoutPrematureDelivery() throws {
        let delegate = SyntheticEmailPromise()
        let provider = NSFilePromiseProvider(fileType: "com.apple.mail.email", delegate: delegate)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects([provider]))
        let receiver = MailPromiseReceiver(destination: URL(fileURLWithPath: "/unused"), ready: { _ in XCTFail("Recognition must not receive a promise") }, failed: { XCTFail($0) })
        XCTAssertTrue(receiver.accepts(pasteboard))
        let promises = try XCTUnwrap(pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver])
        XCTAssertEqual(promises.count, 1)
        XCTAssertTrue(promises[0].fileTypes.contains("com.apple.mail.email"))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("ordinary text", forType: .string))
        XCTAssertFalse(receiver.accepts(pasteboard))
        pasteboard.clearContents()
        let tooMany = (0..<21).map { _ in NSFilePromiseProvider(fileType: "com.apple.mail.email", delegate: delegate) }
        XCTAssertTrue(pasteboard.writeObjects(tooMany))
        var rejection: String?
        let bounded = MailPromiseReceiver(destination: URL(fileURLWithPath: "/unused"), ready: { _ in XCTFail("Too many promises must not be received") }, failed: { rejection = $0 })
        XCTAssertFalse(bounded.receive(pasteboard))
        XCTAssertTrue(rejection?.contains("20") == true)
        withExtendedLifetime(delegate) {}; withExtendedLifetime(provider) {}
    }
}
