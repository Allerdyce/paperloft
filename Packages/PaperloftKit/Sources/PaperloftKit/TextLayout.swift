import Foundation

/// A recognized text fragment in normalized page coordinates (origin at bottom left).
public struct TextFragment: Sendable {
    public let text: String
    public let bounds: CGRect
    public let baselineSlope: Double

    public init(text: String, bounds: CGRect, baselineSlope: Double = 0) {
        self.text = text; self.bounds = bounds; self.baselineSlope = baselineSlope
    }
}

public enum TextLayout {
    /// Retain same-row label/value relationships that Vision may return as separate observations.
    public static func readingOrder(_ fragments: [TextFragment]) -> String {
        let fragments = fragments.filter { !$0.text.isEmpty && $0.bounds.width > 0 && $0.bounds.height > 0 }
        guard !fragments.isEmpty else { return "" }
        let slopes = fragments.filter { $0.bounds.width > 0.08 && $0.baselineSlope.isFinite }
            .map(\.baselineSlope).sorted()
        let slope = slopes.isEmpty ? 0 : slopes[slopes.count / 2]
        func baseline(_ fragment: TextFragment) -> Double {
            fragment.bounds.midY - slope * fragment.bounds.midX
        }
        let sorted = fragments.sorted {
            let a = baseline($0), b = baseline($1)
            return a == b ? $0.bounds.minX < $1.bounds.minX : a > b
        }
        var rows: [[TextFragment]] = []
        for fragment in sorted {
            if let last = rows.last {
                let center = last.map(baseline).reduce(0, +) / Double(last.count)
                let height = last.map { $0.bounds.height }.min() ?? fragment.bounds.height
                if abs(baseline(fragment) - center) <= min(height, fragment.bounds.height) * 0.6 {
                    rows[rows.count - 1].append(fragment)
                    continue
                }
            }
            rows.append([fragment])
        }
        return rows.map { row in
            row.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text).joined(separator: "  ")
        }.joined(separator: "\n")
    }
}
