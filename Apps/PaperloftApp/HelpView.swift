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
            "With Paperloft Pro, a watched folder (Settings › General) sends new files to your Inbox."
        ]),
        Topic(id: "review", title: "Reviewing and filing", symbol: "checkmark.circle", lines: [
            "Every document waits in the Inbox for your confirmation. Nothing is filed without it.",
            "Check the highlighted fields, correct anything that's wrong, then press Return or click Confirm to file. Tab moves between fields. If Paperloft couldn't verify the total, Return takes you to it instead; click Confirm or press ⌘Return to file it as shown. The Receipt menu also has Confirm and File (⌘Return) and Next and Previous Document (⌘] and ⌘[).",
            "Issue means a field needs your attention or the document type couldn't be confirmed. Remove takes a document out of the Inbox without filing it; Edit › Undo (⌘Z) brings it back, and the original file is never changed.",
            "Paperloft files a copy and leaves your original in place. You can choose Move in Settings › Filing. It never overwrites a file, and deleting from the Library moves the file to Recently Deleted rather than erasing it."
        ]),
        Topic(id: "undo", title: "Finding and undoing", symbol: "clock.arrow.circlepath", lines: [
            "Library lists every filed document, with search and filters. Choose Edit › Find… (⌘F) to search, and click a column heading to sort by it.",
            "History lists each filing. Undo there returns the document to your Inbox with the values you confirmed. Right after filing or removing, Edit › Undo (⌘Z) or Undo in the notice does the same."
        ]),
        Topic(id: "export", title: "Tax & Accountant Export and Shortcuts", symbol: "square.and.arrow.up", lines: [
            "In Library, choose Tax & Accountant Export…, or choose File › Tax & Accountant Export… (⇧⌘E), for a summary PDF, a CSV and the documents by category, optionally as a ZIP. Tax & Accountant Export is part of Paperloft Pro.",
            "Shortcuts offers File Document, Open Inbox, Total Spent and Export Accountant Pack. Export Accountant Pack needs Paperloft Pro and returns exports up to 100 MB; make larger ones from the app.",
            "Categories are for organizing records. Paperloft doesn't give tax advice."
        ]),
        Topic(id: "pro", title: "Free and Pro", symbol: "star", lines: [
            "Free includes 25 automatic reads each calendar month; samples don't count. Filling in details yourself, browsing and undo are always free.",
            "Paperloft Pro, yearly with a 7-day free trial or a one-time purchase, reads every document automatically and adds the watched folder, Tax & Accountant Export and Shortcuts export. Prices appear in your currency before you buy.",
            "When a month's reads are used, new documents wait in the Inbox. Choose Fill In Details to have the basic reader fill in what it can for you to check, or upgrade. Settings › General › Paperloft Pro shows your usage and has Restore Purchases.",
            "A subscription renews automatically until you cancel it in your App Store account settings."
        ]),
        Topic(id: "keyboard", title: "Keyboard shortcuts", symbol: "keyboard", lines: [
            "⌘1 Inbox, ⌘2 Library, ⌘3 History. ⌘, opens Settings.",
            "In the Inbox: ↑ and ↓ move between documents, Tab moves between fields, Return confirms, and ⌘Return confirms a total Paperloft asked you to check. ⌘Z undoes the last filing or removal.",
            "⌘I imports files, ⇧⌘V pastes an image, ⌘F finds in the Library, and ⇧⌘E opens Tax & Accountant Export."
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
        }
        // An opaque page like a document, so text always sits on a known background.
        .background(Color(nsColor: .textBackgroundColor))
        .frame(minWidth: 520, idealWidth: 640, minHeight: 480, idealHeight: 720)
            // A title bar separator, so text doesn't scroll under the title.
            .toolbarBackground(.visible, for: .windowToolbar)
            .accessibilityElement(children: .contain).accessibilityLabel("Paperloft Help")
            .background(WindowAccessibility(label: "Paperloft Help"))
            .accessibilityIdentifier("help.root")
    }
}
