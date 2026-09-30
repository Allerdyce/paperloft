import SwiftUI

/// In-app Help (AC-20). Describes only behaviour the current build ships; keep it in step with
/// SUPPORT.md and PRIVACY.md. Body text uses callout size or larger for legibility and the audit.
struct HelpView: View {
    private struct Topic: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let lines: [String]
    }

    private let topics: [Topic] = [
        Topic(id: "start", title: "Getting started", symbol: "sparkles", lines: [
            "Choose a library folder when Paperloft asks, or later in Settings › General › Library. Filed documents are ordinary files there, sorted into year and category folders."
        ]),
        Topic(id: "add", title: "Adding documents", symbol: "tray.and.arrow.down", lines: [
            "Drag PDFs, images (PNG, JPEG, HEIC, TIFF) or saved emails (.eml) onto the window, or onto the window that opens from the menu bar item.",
            "Choose File › Import Receipts…, or copy an image and choose Edit › Paste Image (⇧⌘V).",
            "In Finder, choose Share › Paperloft Receipts. To scan paper, choose File › Import From Device › Scan Documents, listed under your iPhone or iPad.",
            "With Paperloft Pro, a watched folder (Settings › General) sends new files to your Inbox automatically."
        ]),
        Topic(id: "review", title: "Reviewing and filing", symbol: "checkmark.circle", lines: [
            "Every document waits in the Inbox for your confirmation. Nothing is filed without it.",
            "Check the highlighted fields, correct anything that's wrong, then press Return or click Confirm to file. Tab moves between fields. The Receipt menu also has Confirm and File (⌘Return) and Next and Previous Document (⌘] and ⌘[).",
            "Issue means a field needs your attention or the document type couldn't be confirmed. Remove sets a document aside without filing it.",
            "Paperloft files a copy and leaves your original in place. You can choose Move in Settings › Filing. It never overwrites a file, and deleting from the Library moves the file to Recently Deleted rather than erasing it."
        ]),
        Topic(id: "undo", title: "Finding and undoing", symbol: "clock.arrow.circlepath", lines: [
            "Library lists every filed document, with search and filters.",
            "History lists each filing. Undo any of them there, or choose Edit › Undo Last Filing (⌘Z) for the most recent one."
        ]),
        Topic(id: "export", title: "Accountant pack and Shortcuts", symbol: "square.and.arrow.up", lines: [
            "In Library, choose Tax & Accountant Export…, or choose File › Export for Accountant… (⇧⌘E), for a summary PDF, a CSV and the documents by category, optionally as a ZIP.",
            "Shortcuts offers File Document, Open Inbox, Total Spent and Export Accountant Pack. Export Accountant Pack needs Paperloft Pro and returns packs up to 100 MB; export larger packs from the app.",
            "Categories are for organizing records. Paperloft doesn't give tax advice."
        ]),
        Topic(id: "privacy", title: "Privacy", symbol: "lock", lines: [
            "Paperloft reads documents on your Mac with on-device Apple Intelligence and text recognition. It has no network access, no analytics and no account."
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Paperloft Help").font(.largeTitle.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("help.title")
                ForEach(topics) { topic in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(topic.title, systemImage: topic.symbol).font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("help.topic.\(topic.id)")
                        ForEach(topic.lines, id: \.self) { line in
                            Text(line).font(.body).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Getting help", systemImage: "envelope").font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("help.topic.support")
                    Text("Email support@paperloft.app with your Mac model and macOS version. Please don't send documents unless we ask.")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Link("Email Support", destination: URL(string: "mailto:support@paperloft.app")!)
                            .accessibilityIdentifier("help.emailSupport")
                        Link("Privacy Policy", destination: URL(string: "https://paperloft.app/privacy/")!)
                            .accessibilityIdentifier("help.privacyPolicy")
                    }.font(.body)
                }
                Text("Paperloft Receipts is made by EvidencePair LLC.").font(.callout).foregroundStyle(.primary)
            }.padding(28).frame(maxWidth: 640, alignment: .leading)
        }.frame(minWidth: 520, idealWidth: 640, minHeight: 480, idealHeight: 720)
            .accessibilityIdentifier("help.root")
    }
}
