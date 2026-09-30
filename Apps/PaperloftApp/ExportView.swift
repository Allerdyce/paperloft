import PaperloftKit
import SwiftUI

struct ExportView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private static let today = Calendar.current.dateComponents([.year, .month], from: Date())
    @State private var period = "Year"
    @State private var year = today.year ?? 2026
    // The quarter we're in, so a mid-year export starts from the most recent receipts.
    @State private var quarter = ((today.month ?? 1) - 1) / 3 + 1
    @State private var start = Calendar.current.date(from: DateComponents(year: today.year, month: 1, day: 1)) ?? Date()
    @State private var end = Date()
    @State private var zipped = false
    private var years: [Int] { Set(model.allDocuments.map(\.receipt.date.year) + [Self.today.year ?? 2026]).sorted(by: >) }
    private var range: ExportDateRange? {
        switch period {
        case "Quarter": return try? ExportDateRange.quarter(year: year, quarter: quarter)
        case "Custom":
            guard let first = Self.receiptDate(start), let last = Self.receiptDate(end) else { return nil }
            return try? ExportDateRange(start: first, end: last)
        default: return try? ExportDateRange.year(year)
        }
    }
    private static func receiptDate(_ date: Date) -> ReceiptDate? {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return try? ReceiptDate(year: year, month: month, day: day)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Tax & Accountant Export", systemImage: "doc.text").font(.title2.weight(.semibold))
            if let error = model.exportError {
                Text(error).foregroundStyle(.primary).accessibilityIdentifier("export.error")
            }
            if let result = model.exportResult {
                Label("Export complete", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Color.accentColor)
                Text("\(result.documentCount) \(result.documentCount == 1 ? "document" : "documents") copied, with transactions.csv and summary.pdf.")
                    .accessibilityIdentifier("export.result")
                Text(result.folderURL.path).font(.callout).textSelection(.enabled)
                HStack {
                    Button("View Summary") { model.quickLookURL = result.folderURL.appendingPathComponent("summary.pdf"); dismiss() }
                        .accessibilityIdentifier("export.summary")
                    Button("Reveal Pack") { model.revealExport() }.accessibilityIdentifier("export.reveal")
                }
            } else {
                Text("Share your filed receipts and recorded amounts with your accountant.")
                    .foregroundStyle(.secondary)
                GroupBox("Included in your export") {
                    VStack(alignment: .leading, spacing: 10) {
                        included("Transactions CSV — dates, merchants, categories, totals and recorded tax", symbol: "tablecells")
                        included("Summary PDF — category, month and recorded-tax totals", symbol: "doc.richtext")
                        included("Receipt files — copies of your filed originals, grouped by category", symbol: "folder")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                // One fixed label column and two rows in every mode, so switching Period never moves or resizes the sheet.
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 14) {
                    GridRow {
                        rowLabel("Period")
                        Picker("Period", selection: $period) {
                            Text("Calendar year").tag("Year"); Text("Quarter").tag("Quarter"); Text("Custom dates").tag("Custom")
                        }.pickerStyle(.segmented).labelsHidden().fixedSize().accessibilityIdentifier("export.period")
                    }
                    GridRow {
                        rowLabel(period == "Custom" ? "Dates" : "Year")
                        HStack(spacing: 12) {
                            if period == "Custom" {
                                DatePicker("From", selection: $start, displayedComponents: .date)
                                    .datePickerStyle(.field).labelsHidden().accessibilityIdentifier("export.start")
                                Text("through").foregroundStyle(.secondary).accessibilityHidden(true)
                                DatePicker("Through", selection: $end, displayedComponents: .date)
                                    .datePickerStyle(.field).labelsHidden().accessibilityIdentifier("export.end")
                            } else {
                                Picker("Year", selection: $year) {
                                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                                }.labelsHidden().fixedSize().accessibilityIdentifier("export.year")
                                if period == "Quarter" {
                                    Picker("Quarter", selection: $quarter) {
                                        ForEach(1...4, id: \.self) { Text("Q\($0)").tag($0) }
                                    }.pickerStyle(.segmented).labelsHidden().fixedSize().accessibilityIdentifier("export.quarter")
                                }
                            }
                        }.frame(minHeight: 28)
                    }
                    GridRow {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        Toggle("Also create a ZIP archive", isOn: $zipped).toggleStyle(.checkbox).accessibilityIdentifier("export.zip")
                    }
                }
                if period == "Custom" && range == nil {
                    Text("The end date is before the start date.").font(.callout).foregroundStyle(.orange).accessibilityIdentifier("export.validation")
                }
                Text("Only filed receipts dated within this period are included. Dates are inclusive; finish reviewing and filing inbox receipts first.").font(.callout)
                Text("Currencies stay separate. Missing tax stays blank in the CSV and is counted as unknown in the summary. This pack does not calculate deductions or file a tax return.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button(model.exportResult == nil ? "Cancel" : "Done") { dismiss() }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("export.close").disabled(model.busy)
                Spacer()
                if model.busy { ProgressView().controlSize(.small).accessibilityLabel("Creating accountant pack") }
                if model.exportResult == nil {
                    Button("Choose Destination & Export…") { if let range { Task { await model.export(range: range, zipped: zipped) } } }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .disabled(range == nil || model.busy).accessibilityIdentifier("export.create")
                }
            }
        }.padding(28).frame(width: 600)
            .accessibilityElement(children: .contain).accessibilityLabel("Tax and accountant export")
    }
    private func rowLabel(_ title: String) -> some View {
        Text(title).frame(width: 64, alignment: .trailing).accessibilityHidden(true)
    }
    /// A fixed-width icon column keeps the three rows' text aligned.
    private func included(_ title: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).frame(width: 20).foregroundStyle(Color.accentColor).accessibilityHidden(true)
            Text(title)
        }
    }
}
