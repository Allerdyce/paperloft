import AppKit
import CoreGraphics
import Foundation
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let examples = [
    ("01-office", "Maple Desk Supply", "2026-09-04", "Printer paper and pens", "24.00", "1.92", "25.92"),
    ("02-meal", "Juniper Cafe", "2026-09-08", "Lunch and coffee", "18.50", "1.48", "19.98"),
    ("03-travel", "Harbor Hotel", "2026-09-12", "One night lodging", "120.00", "12.00", "132.00"),
    ("04-software", "Clearpath Software", "2026-09-15", "Software subscription", "30.00", "0.00", "30.00"),
    ("05-utilities", "Meadow Internet", "2026-09-18", "Internet service", "65.00", "0.00", "65.00")
]
for row in examples {
    let url = output.appendingPathComponent(row.0 + ".pdf")
    var box = CGRect(x: 0, y: 0, width: 420, height: 560)
    guard let consumer = CGDataConsumer(url: url as CFURL), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { fatalError("PDF context unavailable") }
    context.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSColor.white.setFill(); NSBezierPath(rect: box).fill()
    let rows = [row.1, "RECEIPT", "Date: " + row.2, "", row.3, "Subtotal  $" + row.4, "Tax  $" + row.5, "TOTAL PAID  $" + row.6, "Currency: USD", "", "Synthetic sample — no real purchase", "Made for Paperloft Receipts"]
    for (i, line) in rows.enumerated() {
        (line as NSString).draw(at: CGPoint(x: 28, y: 510 - i * 35), withAttributes: [.font: NSFont.systemFont(ofSize: i == 0 ? 22 : 15, weight: i == 0 || i == 7 ? .semibold : .regular), .foregroundColor: NSColor.black])
    }
    NSGraphicsContext.restoreGraphicsState(); context.endPDFPage(); context.closePDF()
}
