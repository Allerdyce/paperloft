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
    let id: String
    let kind: String
    let vendor: String?
    let date: String?
    let total: String?
    let category: String?
    let tags: [String]
    let layout: Int
}
@main
struct Fixtures {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 2 else { throw error("Pass a new output directory") }
        let destination = URL(fileURLWithPath: args[1], isDirectory: true)
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
        let totalWords = ["TOTAL", "Grand total", "Amount paid", "Total due", "Balance due", "TOTAL USD", "Total", "GRAND TOTAL", "Amount paid", "TOTAL", "Total due", "Balance due"]
        let ci = CIContext()
        var random = Random()
        var labels = Data()
        var financialIndex = 0
        for index in 0..<150 {
            let id = String(format: "document-%03d", index + 1)
            let layout = index % 12
            let isNonReceipt = index % 10 == 9
            let long = !isNonReceipt && index % 4 == 1
            let confusable = !isNonReceipt && index % 4 == 0
            let photo = index % 2 == 0
            let merchant = financialIndex % 40
            if !isNonReceipt { financialIndex += 1 }
            let group = merchant / 5
            let vendor = merchantGroups[group][merchant % 5]
            let month = 1 + random.next(9), day = 1 + random.next(28)
            let date = String(format: "2026-%02d-%02d", month, day)
            let printedDate: String
            switch layout % 3 {
            case 0: printedDate = date
            case 1: printedDate = "\(month)/\(day)/2026"
            default: printedDate = "\(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"][month-1]) \(day), 2026"
            }
            let subtotal = 1000 + random.next(40000)
            let tax = (subtotal * 75 + 500) / 1000
            let tip = group == 1 ? subtotal / 5 : 0
            let total = subtotal + tax + tip
            let kind = isNonReceipt ? "not_receipt" : (group == 3 ? "bill" : (layout % 4 == 2 ? "invoice" : "receipt"))
            var lines: [(String, Bool)] = []
            if isNonReceipt {
                lines = [("NEIGHBORHOOD NOTICE", true), ("Community Skills Exchange", true), ("Saturday workshop schedule", false), ("10:00 Garden planning", false), ("11:30 Bicycle maintenance", false), ("14:00 Volunteer orientation", false), ("Bring a notebook and a reusable cup.", false), ("Questions: visit the information desk.", false), ("This announcement is not a purchase record.", false)]
            } else {
                if layout % 4 == 0 { lines.append((kind.uppercased(), false)) }
                lines.append((vendor, true))
                if layout % 4 != 0 { lines.append((kind == "bill" ? "UTILITY BILL" : kind.uppercased(), false)) }
                lines.append(("Document #\(42000 + index)", false))
                lines.append(("Date: \(printedDate)", false))
                if kind == "invoice" { lines.append(("Due date: 12/31/2026", false)) }
                lines.append((String(repeating: layout % 2 == 0 ? "-" : "=", count: 34), false))
                let count = long ? 26 + random.next(12) : 2 + random.next(5)
                let unit = subtotal / count
                for row in 0..<count {
                    let amount = row == count - 1 ? subtotal - unit * (count - 1) : unit
                    let descriptions = ["Service charge", "Supplies", "Standard item", "Order item", "Professional service", "Materials"]
                    lines.append(("\(row + 1). \(descriptions[(row + layout) % descriptions.count])  $\(money(amount))", false))
                }
                lines.append(("Subtotal  $\(money(subtotal))", false))
                lines.append(("Sales tax  $\(money(tax))", false))
                if tip > 0 { lines.append(("Tip  $\(money(tip))", false)) }
                lines.append(("\(totalWords[layout])  $\(money(total))", true))
                if confusable {
                    let tendered = ((total / 1000) + 1) * 1000
                    lines.append(("Cash tendered  $\(money(tendered))", false))
                    lines.append(("Change  $\(money(tendered - total))", false))
                    lines.append(("Rewards balance $\(money(random.next(5000)))", false))
                } else { lines.append(("Card ending 2048 - approved", false)) }
                lines.append(("Thank you for your business", false))
            }
            let width = [740, 820, 900, 760, 960, 850, 800, 920, 780, 1000, 840, 880][layout]
            let spacing = [35, 39, 36, 38, 40, 35, 38, 40, 36, 38, 40, 36][layout]
            let height = max(650, 130 + lines.count * spacing)
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw error("Image allocation failed") }
            context.setFillColor(CGColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            for (row, line) in lines.enumerated() {
                let font: NSFont = layout % 3 == 0 ? .monospacedSystemFont(ofSize: line.1 ? 27 : 23, weight: line.1 ? .bold : .regular) : .systemFont(ofSize: line.1 ? 28 : 24, weight: line.1 ? .semibold : .regular)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedWhite: photo ? 0.18 : 0.08, alpha: 1)]
                let text = line.0 as NSString
                let center = line.1 && row < 3 && layout % 2 == 1
                let x = center ? max(25, (Double(width) - text.size(withAttributes: attributes).width) / 2) : Double(35 + (layout % 3) * 8)
                text.draw(at: CGPoint(x: x, y: Double(height - 65 - row * spacing)), withAttributes: attributes)
            }
            NSGraphicsContext.restoreGraphicsState()
            guard var image = context.makeImage() else { throw error("Image rendering failed") }
            if photo {
                let base = CIImage(cgImage: image)
                let w = CGFloat(width), h = CGFloat(height)
                let tilt = CGFloat(8 + random.next(18))
                let perspective = base.applyingFilter("CIPerspectiveTransform", parameters: ["inputTopLeft": CIVector(x: tilt, y: h - 8), "inputTopRight": CIVector(x: w - 9, y: h - tilt), "inputBottomLeft": CIVector(x: 5, y: 12), "inputBottomRight": CIVector(x: w - tilt, y: 0)])
                let softened = perspective.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.3 + Double(random.next(5)) / 10])
                let canvas = CIImage(color: CIColor(red: 0.57, green: 0.52, blue: 0.44)).cropped(to: CGRect(x: -25, y: -25, width: w + 50, height: h + 50))
                let result = softened.composited(over: canvas)
                guard let rendered = ci.createCGImage(result, from: canvas.extent) else { throw error("Photo rendering failed") }
                image = rendered
            }
            let file = destination.appendingPathComponent(id + (photo ? ".jpg" : ".png"))
            guard let writer = CGImageDestinationCreateWithURL(file as CFURL, (photo ? UTType.jpeg.identifier : UTType.png.identifier) as CFString, 1, nil) else { throw error("Image output failed") }
            CGImageDestinationAddImage(writer, image, photo ? [kCGImageDestinationLossyCompressionQuality: 0.65 + Double(random.next(25)) / 100] as CFDictionary : nil)
            guard CGImageDestinationFinalize(writer) else { throw error("Image finalization failed") }
            let tags = [(photo, "photo"), (long, "long"), (confusable, "confusable")].filter { $0.0 }.map { $0.1 }
            let label = Label(id: id, kind: kind, vendor: isNonReceipt ? nil : vendor, date: isNonReceipt ? nil : date, total: isNonReceipt ? nil : money(total), category: isNonReceipt ? nil : categories[group], tags: tags, layout: layout)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            labels.append(try encoder.encode(label)); labels.append(10)
        }
        try labels.write(to: destination.appendingPathComponent("labels.jsonl"), options: .atomic)
        print("Generated 150 documents, 12 layout variants, 40 merchant definitions.")
    }
    static func money(_ cents: Int) -> String { String(format: "%d.%02d", cents / 100, cents % 100) }
    static func error(_ message: String) -> NSError { NSError(domain: "ReceiptFixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
