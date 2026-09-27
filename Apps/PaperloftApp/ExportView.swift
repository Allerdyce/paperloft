import PaperloftKit
import SwiftUI

struct ExportView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var period = "Year"
    @State private var year = String(Calendar.current.component(.year, from: Date()))
    @State private var quarter = "1"
    @State private var start = ""
    @State private var end = ""
    @State private var zipped = false
    private var range: ExportDateRange? {
        switch period {
        case "Quarter": return try? ExportDateRange.quarter(year: Int(year) ?? 0, quarter: Int(quarter) ?? 0)
        case "Custom":
            guard let first = try? ReceiptDate(iso8601: start), let last = try? ReceiptDate(iso8601: end) else { return nil }
            return try? ExportDateRange(start: first, end: last)
        default: return try? ExportDateRange.year(Int(year) ?? 0)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Tax & Accountant Export", systemImage: "doc.text").font(.title2.weight(.semibold))
            if let error = model.exportError {
                Text(error).foregroundStyle(.primary).accessibilityIdentifier("export.error")
            }
            if let result = model.exportResult {
                Label("Export complete", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Color.accentColor)
                Text("\(result.documentCount) documents copied, with transactions.csv and summary.pdf.")
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
                        Label("Transactions CSV — dates, merchants, categories, totals and recorded tax", systemImage: "tablecells")
                        Label("Summary PDF — category, month and recorded-tax totals", systemImage: "doc.richtext")
                        Label("Receipt files — copies of your filed originals, grouped by category", systemImage: "folder")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                Form {
                    Picker("Period", selection: $period) {
                        Text("Calendar year").tag("Year"); Text("Quarter").tag("Quarter"); Text("Custom dates").tag("Custom")
                    }.pickerStyle(.segmented).accessibilityIdentifier("export.period")
                    if period != "Custom" {
                        TextField("Year", text: $year).accessibilityIdentifier("export.year")
                        if period == "Quarter" {
                            Picker("Quarter", selection: $quarter) {
                                ForEach(1...4, id: \.self) { Text("Q\($0)").tag(String($0)) }
                            }.pickerStyle(.segmented).accessibilityIdentifier("export.quarter")
                        }
                    } else {
                        TextField("From (YYYY-MM-DD)", text: $start).accessibilityIdentifier("export.start")
                        TextField("Through (YYYY-MM-DD)", text: $end).accessibilityIdentifier("export.end")
                    }
                    Toggle("Also create a ZIP archive", isOn: $zipped).accessibilityIdentifier("export.zip")
                }
                Text("Only filed receipts dated within this period are included. Dates are inclusive; finish reviewing and filing inbox receipts first.").font(.callout)
                Text("Currencies stay separate. Missing tax stays blank in the CSV and is counted as unknown in the summary. This pack does not calculate deductions or file a tax return.")
                    .font(.callout).foregroundStyle(.secondary)
                if range == nil { Text("Enter a valid year or date range.").foregroundStyle(.orange).accessibilityIdentifier("export.validation") }
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
}
