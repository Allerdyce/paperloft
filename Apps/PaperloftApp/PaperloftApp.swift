import SwiftUI
import AppIntents
import PaperloftKit

@main
struct PaperloftApp: App {
    var body: some Scene {
        WindowGroup("Paperloft Receipts") { LibraryView() }
        Settings { Text("Paperloft Receipts\n© 2026 EvidencePair LLC")
            .multilineTextAlignment(.center).padding(40) }
    }
}

struct LibraryView: View {
    @State private var selection = "Inbox"
    private func navigationButton(_ title: String, symbol: String) -> some View {
        Button { selection = title } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .listRowBackground(selection == title ? Color.accentColor.opacity(0.15) : Color.clear)
        .accessibilityIdentifier("sidebar." + title.lowercased())
    }
    var body: some View {
        NavigationSplitView {
            List {
                navigationButton("Inbox", symbol: "tray")
                navigationButton("Library", symbol: "folder")
                navigationButton("History", symbol: "clock.arrow.circlepath")
            }
            .navigationTitle("Paperloft")
        } detail: {
            VStack(spacing: 12) {
                Image(systemName: selection == "Inbox" ? "tray" : "folder")
                    .font(.system(size: 40)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(selection == "Inbox" ? "A place for your paperwork" : selection)
                    .font(.title2.bold())
                    .accessibilityIdentifier("content.title")
                Text("Paperloft is being built. Receipt import and library setup are coming next.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(selection)
        }
        .tint(Color(red: 0.06, green: 0.29, blue: 0.18))
        .frame(minWidth: 800, minHeight: 520)
    }
}
