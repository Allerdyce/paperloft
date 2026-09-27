import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

struct Random {
    var state: UInt64 = 0x50415045524c4f46
    mutating func next(_ limit: Int) -> Int {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Int(state % UInt64(limit))
    }
}
struct Label: Encodable {
    let id: String; let kind: String; let vendor: String?; let date: String?
    let total: String?; let category: String?; let tags: [String]; let layout: Int
}
@MainActor
struct Canvas {
    let context: CGContext
    let width: Int
    let height: Int
    let thermal: Bool
    func text(_ value: String, _ x: Double, _ y: Double, size: Double = 23, bold: Bool = false, right: Bool = false) {
        let font: NSFont = thermal ? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular) : .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)]
        let string = value as NSString
        string.draw(at: CGPoint(x: right ? x - string.size(withAttributes: attributes).width : x, y: Double(height) - y - size - 5), withAttributes: attributes)
    }
    func rule(_ x: Double, _ y: Double, _ length: Double) {
        context.setStrokeColor(CGColor(gray: 0.35, alpha: 1)); context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: Double(height) - y)); context.addLine(to: CGPoint(x: x + length, y: Double(height) - y)); context.strokePath()
    }
    func pair(_ label: String, _ amount: String, _ y: Double, left: Double = 40, right: Double? = nil, bold: Bool = false) {
        text(label, left, y, bold: bold)
        text(amount, right ?? Double(width - 40), y, bold: bold, right: true)
    }
}
@main
struct Fixtures {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw error("Pass a new output directory") }
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw error("Output already exists; locked fixtures must never be overwritten") }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let categories = ["Office supplies", "Meals", "Travel", "Utilities", "Advertising", "Software", "Vehicle", "Other expenses"]
        let merchantGroups = [
            ["Acorn Office", "Birch Stationery", "Cedar Paper", "Delta Printer Supply", "Elm Office Depot"],
            ["Fern Cafe", "Grove Restaurant", "Harbor Coffee", "Iris Diner", "Juniper Bakery"],
            ["Kestrel Hotel", "Larch Airline", "Meadow Lodging", "North Taxi", "Orchard Rail"],
            ["Pine Electric", "Quartz Internet", "River Water Service", "Spruce Utility", "Tamarack Electric"],
            ["Union Advertising", "Vista Marketing", "Willow Print Studio", "Xenia Advertising", "Yarrow Marketing"],
            ["Zenith Software", "Amber Hosting", "Beacon Cloud Subscription", "Copper Software", "Dawn Hosting"],
            ["Evergreen Fuel", "Falcon Gas Station", "Granite Auto Service", "Hearth Fuel", "Indigo Auto Service"],
            ["Jasper Workshop", "Keystone Repair", "Lantern Services", "Marble Rentals", "Noble Studio"]
        ]
        // Every ID selects a different placement/transaction structure, not a font variant.
        // 0 thermal inline; 1 invoice quantity table; 2 top summary; 3 account sidebar;
        // 4 two-column basket; 5 item/amount stacked; 6 remittance slip; 7 payment stub;
        // 8 reverse-column ledger; 9 sectioned item groups; 10 compact card slip;
        // 11 service statement with right-hand account panel.
        let itemNames = [
            ["Copy paper", "Ink cartridge", "Notebooks", "Desk organizer", "Envelopes", "Pens"],
            ["Lunch plate", "Coffee", "Soup", "Sandwich", "Salad", "Pastry"],
            ["Travel booking", "Passenger fare", "Reservation fee", "Luggage service", "Transfer", "Travel service"],
            ["Monthly service", "Metered usage", "Service connection", "Delivery charge", "Account service", "Usage charge"],
            ["Ad placement", "Campaign artwork", "Print campaign", "Media service", "Design work", "Ad production"],
            ["Software license", "Cloud storage", "Hosting plan", "Software support", "User seat", "Subscription"],
            ["Fuel", "Vehicle service", "Oil", "Filter", "Tire service", "Auto parts"],
            ["Repair labor", "Equipment rental", "Materials", "Workshop service", "Setup fee", "Service charge"]
        ]
        let ci = CIContext()
        var random = Random(); var labels = Data(); var financialIndex = 0
        for index in 0..<150 {
            let id = String(format: "document-%03d", index + 1), layout = index % 12
            let nonReceipt = index % 10 == 9, photo = index % 2 == 0
            let long = !nonReceipt && index % 4 == 1, confusable = !nonReceipt && index % 4 == 0
            let merchant = financialIndex % 40
            if !nonReceipt { financialIndex += 1 }
            let group = merchant / 5, vendor = merchantGroups[merchant / 5][merchant % 5]
            let month = 1 + random.next(9), day = 1 + random.next(28)
            let date = String(format: "2026-%02d-%02d", month, day)
            let printedDate = layout % 3 == 0 ? date : (layout % 3 == 1 ? "\(month)/\(day)/2026" : "\(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"][month - 1]) \(day), 2026")
            let subtotal = 1000 + random.next(40000), count = long ? 26 + random.next(12) : 3 + random.next(4)
            let tax = (subtotal * 75 + 500) / 1000, tip = group == 1 ? subtotal / 5 : 0
            let total = subtotal + tax + tip
            let kind = nonReceipt ? "not_receipt" : (group == 3 ? "bill" : ([1, 3, 6, 8, 11].contains(layout) ? "invoice" : "receipt"))
            let heading = kind == "bill" ? "UTILITY BILL" : kind.uppercased()
            let weights = (0..<count).map { _ in 1 + random.next(9) }
            let weightTotal = weights.reduce(0, +)
            var amounts = weights.map { subtotal * $0 / weightTotal }
            amounts[count - 1] += subtotal - amounts.reduce(0, +)
            let rowHeight = layout == 5 ? 66 : 38
            let rows = layout == 4 ? (count + 1) / 2 : count
            let width = [760, 1120, 900, 1180, 1300, 780, 1100, 1000, 1060, 920, 780, 1200][layout]
            let height = max(950, 760 + rows * rowHeight + (layout == 9 ? ((count + 3) / 4) * 40 : 0))
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw error("Image allocation failed") }
            context.setFillColor(CGColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let c = Canvas(context: context, width: width, height: height, thermal: [0, 5, 10].contains(layout))
            if nonReceipt {
                c.text("COMMUNITY NOTICE", 40, 40, size: 32, bold: true)
                c.text("Skills exchange / Saturday programme", 40, 110)
                c.rule(40, 160, Double(width - 80))
                c.text("10:00 Garden planning", 40, 190); c.text("11:30 Bicycle maintenance", 40, 260)
                c.text("Bring a notebook and reusable cup.", 40, 370)
                c.text("This is an announcement, not a purchase record.", 40, 440, size: 20)
            } else {
                let w = Double(width)
                var itemY = 225.0, itemLeft = 40.0, amountRight = w - 40
                c.text(vendor, 40, 35, size: 30, bold: true)
                switch layout {
                case 1:
                    c.text(heading, w - 40, 40, size: 25, bold: true, right: true)
                    c.text("Issued: \(printedDate)", 40, 110); c.text("Billed to: Walk-in customer", 40, 150)
                    c.text("Due date: 12/31/2026", w - 40, 150, size: 21, right: true)
                    c.text("DESCRIPTION", 40, 215, bold: true); c.text("QTY", w - 275, 215, bold: true)
                    c.text("LINE AMOUNT", w - 40, 215, bold: true, right: true); itemY = 265
                case 2:
                    c.text(heading, 40, 85); c.text("Date: \(printedDate)", w - 40, 85, right: true)
                    c.pair("Subtotal", "$\(money(subtotal))", 135)
                    c.pair("Sales tax", "$\(money(tax))", 173)
                    if tip > 0 { c.pair("Tip", "$\(money(tip))", 211) }
                    c.pair("AMOUNT PAID", "$\(money(total))", 255, bold: true)
                    c.rule(40, 310, w - 80); c.text("Purchase details", 40, 340, bold: true); itemY = 385
                case 3:
                    c.text(heading, 40, 85); c.text("ACCOUNT", 40, 160, bold: true)
                    c.text("Customer 2048", 40, 205); c.text("Date:", 40, 250); c.text(printedDate, 40, 285)
                    c.text("Document \(42000 + index)", 40, 340); c.text("Service details", 420, 145, bold: true)
                    itemLeft = 420; itemY = 195
                case 4:
                    c.text(heading, 40, 85); c.text("Date: \(printedDate)", w - 40, 85, right: true)
                    c.text("BASKET A", 40, 155, bold: true); c.text("BASKET B", w / 2 + 20, 155, bold: true)
                    c.rule(40, 200, w - 80); itemY = 225
                case 5:
                    c.text(heading, 40, 85); c.text("Transaction date: \(printedDate)", 40, 135)
                    c.rule(40, 190, w - 80); itemY = 220
                case 6:
                    c.text(heading, w - 40, 40, bold: true, right: true)
                    c.text("Date: \(printedDate)", 40, 105); c.text("Remit using reference \(42000 + index)", 40, 145)
                    c.text("DESCRIPTION / CHARGE", 40, 210, bold: true); itemY = 255
                case 7:
                    c.text(heading, 40, 85); c.text("Date: \(printedDate)", 40, 130)
                    c.pair("CARD PAYMENT", "$\(money(total))", 185, bold: true)
                    c.text("APPROVED • Card ending 2048", 40, 225); c.rule(40, 280, w - 80)
                    c.text("ITEMIZED RECEIPT", 40, 305, bold: true); itemY = 355
                case 8:
                    c.text(heading, 40, 85); c.text("Issued: \(printedDate)", w - 40, 85, right: true)
                    c.text("CHARGE", 40, 175, bold: true); c.text("DESCRIPTION", 270, 175, bold: true); itemY = 220
                case 9:
                    c.text(heading, 40, 85); c.text("Date: \(printedDate)", 40, 135); itemY = 200
                case 10:
                    c.text("PURCHASE \(heading)", 40, 85); c.text("Date: \(printedDate)", 40, 130)
                    c.text("Card: **** 2048", 40, 170); c.pair("TOTAL", "$\(money(total))", 220, bold: true)
                    c.rule(40, 270, w - 80); c.text("ITEM DETAIL", 40, 295, bold: true); itemY = 340
                case 11:
                    c.text(heading, 40, 85); c.text("SERVICE STATEMENT", 40, 145, bold: true)
                    c.text("ACCOUNT DETAILS", w - 330, 150, bold: true)
                    c.text("Date: \(printedDate)", w - 330, 200, size: 20)
                    c.text("Reference \(42000 + index)", w - 330, 245)
                    c.text("Due: 12/31/2026", w - 330, 290, size: 20)
                    itemY = 215; amountRight = w - 410
                default:
                    c.text(heading, 40, 85); c.text("Date: \(printedDate)", 40, 135)
                    c.text("Register 2 / Transaction \(42000 + index)", 40, 175, size: 20); itemY = 225
                }
                var y = itemY
                for row in 0..<count {
                    let description = itemNames[group][row % 6], amount = "$\(money(amounts[row]))"
                    switch layout {
                    case 0: c.text("\(row + 1) \(description)  \(amount)", 40, y); y += 38
                    case 1:
                        c.text(description, 40, y); c.text("1", w - 255, y); c.text(amount, w - 40, y, right: true); y += 38
                    case 4:
                        let second = row >= (count + 1) / 2, n = second ? row - (count + 1) / 2 : row
                        let left = second ? w / 2 + 20 : 40, right = second ? w - 40 : w / 2 - 30
                        c.text(description, left, itemY + Double(n * 38), size: 21)
                        c.text(amount, right, itemY + Double(n * 38), size: 21, right: true)
                        y = itemY + Double(rows * 38)
                    case 5:
                        c.text("\(row + 1). \(description)", 40, y)
                        c.text("1 @ \(amount)     \(amount)", w - 40, y + 29, size: 21, right: true); y += 66
                    case 8:
                        c.text(amount, 190, y, right: true); c.text(description, 270, y); y += 38
                    case 9:
                        if row % 4 == 0 { c.text("Purchase group \(row / 4 + 1)", 40, y, bold: true); y += 40 }
                        c.pair(description, amount, y, left: 75); y += 38
                    default: c.pair(description, amount, y, left: itemLeft, right: amountRight); y += 38
                    }
                }
                y += 20; c.rule(itemLeft, y, amountRight - itemLeft); y += 20
                let summaryLeft = layout == 1 || layout == 6 ? w / 2 : itemLeft
                if layout != 2 {
                c.pair("Subtotal", "$\(money(subtotal))", y, left: summaryLeft, right: amountRight); y += 38
                c.pair("Sales tax", "$\(money(tax))", y, left: summaryLeft, right: amountRight); y += 38
                if tip > 0 { c.pair("Tip", "$\(money(tip))", y, left: summaryLeft, right: amountRight); y += 38 }
                }
                if ![2, 7, 10].contains(layout) {
                    c.pair(kind == "receipt" ? "TOTAL" : "Balance due", "$\(money(total))", y, left: summaryLeft, right: amountRight, bold: true); y += 48
                }
                if confusable {
                    let cash = ((total / 1000) + 1) * 1000
                    c.pair("Cash tendered", "$\(money(cash))", y, left: itemLeft, right: amountRight); y += 34
                    c.pair("Change", "$\(money(cash - total))", y, left: itemLeft, right: amountRight); y += 34
                }
                if layout == 6 {
                    c.rule(40, y + 5, w - 80); y += 30
                    c.text("DETACH AND RETURN WITH PAYMENT", 40, y, size: 20, bold: true); y += 35
                    c.text("Reference \(42000 + index) / Amount due $\(money(total))", 40, y, size: 20)
                } else { c.text("Thank you / keep for your records", itemLeft, y + 15, size: 20) }
            }
            NSGraphicsContext.restoreGraphicsState()
            guard var image = context.makeImage() else { throw error("Image rendering failed") }
            if photo {
                let base = CIImage(cgImage: image), w = CGFloat(width), h = CGFloat(height)
                let tilt = CGFloat(8 + random.next(18))
                let perspective = base.applyingFilter("CIPerspectiveTransform", parameters: ["inputTopLeft": CIVector(x: tilt, y: h - 8), "inputTopRight": CIVector(x: w - 9, y: h - tilt), "inputBottomLeft": CIVector(x: 5, y: 12), "inputBottomRight": CIVector(x: w - tilt, y: 0)])
                let angle = (Double(random.next(7)) - 3) * .pi / 180
                let rotated = perspective.transformed(by: CGAffineTransform(rotationAngle: angle))
                let softened = rotated.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.3 + Double(random.next(5)) / 10])
                let extent = rotated.extent.insetBy(dx: -25, dy: -25).integral
                let canvas = CIImage(color: CIColor(red: 0.57, green: 0.52, blue: 0.44)).cropped(to: extent)
                guard let rendered = ci.createCGImage(softened.composited(over: canvas), from: extent) else { throw error("Photo rendering failed") }; image = rendered
            }
            let file = destination.appendingPathComponent(id + (photo ? ".jpg" : ".png"))
            guard let writer = CGImageDestinationCreateWithURL(file as CFURL, (photo ? UTType.jpeg.identifier : UTType.png.identifier) as CFString, 1, nil) else { throw error("Image output failed") }
            CGImageDestinationAddImage(writer, image, photo ? [kCGImageDestinationLossyCompressionQuality: 0.65 + Double(random.next(25)) / 100] as CFDictionary : nil)
            guard CGImageDestinationFinalize(writer) else { throw error("Image finalization failed") }
            let tags = [(photo, "photo"), (long, "long"), (confusable, "confusable")].filter { $0.0 }.map { $0.1 }
            let label = Label(id: id, kind: kind, vendor: nonReceipt ? nil : vendor, date: nonReceipt ? nil : date, total: nonReceipt ? nil : money(total), category: nonReceipt ? nil : categories[group], tags: tags, layout: layout)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            labels.append(try encoder.encode(label)); labels.append(10)
        }
        try labels.write(to: destination.appendingPathComponent("labels.jsonl"), options: .atomic)
        print("Generated 150 documents across 12 structural layouts and 40 merchants.")
    }
    static func money(_ cents: Int) -> String { String(format: "%d.%02d", cents / 100, cents % 100) }
    static func error(_ message: String) -> NSError { NSError(domain: "ReceiptFixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
