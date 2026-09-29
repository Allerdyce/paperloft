import Foundation
import CoreGraphics
import CoreText

// Synthetic development corpus only. It is not the independent email holdout.
// Run: swift Tests/Support/GenerateMailFixtures.swift Tests/MailFixtures
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Tests/MailFixtures")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func pdf(_ text: String) throws -> Data {
    let data = NSMutableData()
    var page = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &page, nil) else { throw CocoaError(.fileWriteUnknown) }
    context.beginPDFPage(nil)
    let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
    for (index, line) in text.components(separatedBy: .newlines).enumerated() {
        context.textPosition = CGPoint(x: 48, y: 740 - index * 20)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])), context)
    }
    context.endPDFPage(); context.closePDF()
    return data as Data
}
func encoded(_ data: Data) -> String { data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed]) }
func textPart(_ body: String, html: Bool = false) -> String {
    "Content-Type: text/\(html ? "html" : "plain"); charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n" + encoded(Data(body.utf8))
}
func attachment(_ text: String, name: String) throws -> String {
    "Content-Type: application/pdf; name=\"\(name)\"\r\nContent-Disposition: attachment; filename=\"\(name)\"\r\nContent-Transfer-Encoding: base64\r\n\r\n" + encoded(try pdf(text))
}
let merchants = ["Alder Office", "Birch Cloud", "Cedar Cafe", "Delta Rail", "Elm Print Studio", "Fir Hardware", "Grove Hotel", "Hazel Hosting", "Iris Bakery", "Juniper Taxi", "Kestrel Stationery", "Linden Internet", "Maple Market", "North Software", "Oak Workshop", "Pine Electric"]
var labels: [[String: Any]] = []
for index in 0..<80 {
    let id = String(format: "email-%03d", index + 1)
    let group = index < 28 ? "pdf" : index < 52 ? "body" : index < 64 ? "mixed" : "not_receipt"
    let merchant = merchants[index % merchants.count]
    let date = String(format: "2026-%02d-%02d", 1 + index % 9, 1 + (index * 7) % 27)
    let total = String(format: "%d.%02d", 12 + (index * 37) % 680, (index * 13) % 100)
    let styles = [
        "\(merchant)\nRECEIPT\nDate: \(date)\nOffice supplies\nTotal USD \(total)\nPaid by card",
        "\(merchant)\nTAX INVOICE\nInvoice date: \(date)\nServices completed\nAmount due USD \(total)",
        "\(merchant)\nReceipt for your purchase\nTransaction date: \(date)\nCard payment USD \(total)\nThank you",
        "\(merchant)\nOrder confirmation\nDate: \(date)\nReceipt\nTotal due USD \(total)\nCustomer: Sample Customer",
        "\(merchant)\nReceipt\nDate: \(date)\nPayment summary\nAmount paid USD \(total)\nReturns within 30 days",
        "\(merchant)\nINVOICE\nIssued: \(date)\nAccount: Synthetic account\nGrand total USD \(total)",
        "\(merchant)\nReceipt\nDate: \(date)\nPayment method: Card\nTotal USD \(total)\nKeep this receipt for your records",
        "\(merchant)\nReceipt\nPurchase date: \(date)\nOrder reference: SAMPLE-\(index)\nTotal USD \(total)"
    ]
    let receipt = styles[index % styles.count]
    let kind = [1, 5].contains(index % styles.count) ? "invoice" : "receipt"
    let html = index % 2 == 0
    let body: String
    if group == "body" {
        body = html ? "<!doctype html><html><body><table>" + receipt.components(separatedBy: .newlines).map { "<tr><td>" + $0 + "</td></tr>" }.joined() + "</table><img src=\"https://assets.example.invalid/tracker.png\"></body></html>" : receipt
    } else if group == "not_receipt" {
        let texts = ["Community newsletter\nMeet the team at our upcoming community event.\nRead more about our new opening hours.", "Your account preferences changed\nThis is a security notification.\nNo purchase was made.", "Shipping update\nYour parcel is on its way.\nTrack your delivery from your account.", "Tips for organizing paperwork\nUse folders and categories to find documents quickly.\nThis message is educational."]
        body = texts[index % texts.count]
    } else { body = "Hello Sample Customer,\nPlease find your receipt attached.\nThank you,\nCustomer Support" }
    let boundary = "PaperloftSynthetic-" + id
    var parts = [textPart(body, html: group == "body" && html)]
    if group == "pdf" || group == "mixed" { parts.append(try attachment(receipt, name: "receipt-\(index).pdf")) }
    if group == "mixed" { parts.append(try attachment("Terms and conditions\nRead the service agreement before using this product.\nThis is not a receipt or invoice.\nContact customer support for help.", name: "terms.pdf")) }
    let headers = "From: Forwarding Service <forwarder@example.invalid>\r\nTo: Sample Customer <customer@example.invalid>\r\nDate: Tue, 29 Sep 2026 12:00:00 +0000\r\nSubject: Account message \(index + 1)\r\nMessage-ID: <\(id)@paperloft.example.invalid>\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n\r\n"
    let email = headers + parts.map { "--\(boundary)\r\n" + $0 + "\r\n" }.joined() + "--\(boundary)--\r\n"
    try Data(email.utf8).write(to: destination.appendingPathComponent(id + ".eml"), options: .atomic)
    var label: [String: Any] = ["id": id, "group": group, "expectedPDFParts": group == "mixed" ? 2 : group == "pdf" ? 1 : 0, "expectedReceiptCount": group == "not_receipt" ? 0 : 1, "expectedBodySelected": group == "body" || group == "not_receipt", "bodyContains": group == "body" ? merchant : group == "not_receipt" ? String(body.prefix(20)) : "Please find your receipt attached.", "layout": index % styles.count]
    if group != "not_receipt" { label["receipt"] = ["vendor": merchant, "date": date, "total": total, "kind": kind] }
    labels.append(label)
}
let lines = try labels.map { String(decoding: try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]), as: UTF8.self) }.joined(separator: "\n") + "\n"
try Data(lines.utf8).write(to: destination.appendingPathComponent("labels.jsonl"), options: .atomic)
print("Generated 80 synthetic emails: 28 PDF, 24 body, 12 mixed, 16 non-receipts.")
