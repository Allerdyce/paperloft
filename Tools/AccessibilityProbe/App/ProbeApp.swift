import SwiftUI

@main
struct ProbeApp: App {
    @State private var text = ""
    @State private var selection = "All"
    var body: some Scene {
        Window("Accessibility Probe", id: "main") {
            if ProcessInfo.processInfo.arguments.contains("--settings") {
                VStack(spacing: 14) {
                    Text("Nothing filed yet").font(.title3)
                    Text("Every filing can be undone. Your original documents are preserved.").foregroundStyle(.primary)
                    SettingsLink { Text("Open Settings") }
                }.frame(width: 1180, height: 760)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .navigationTitle("History")
            } else if ProcessInfo.processInfo.arguments.contains("--pdf") {
                PDFProbePanel()
            } else if ProcessInfo.processInfo.arguments.contains("--empty") {
                Color.clear.frame(width: 400, height: 200)
            } else {
                VStack {
                    TextField("Search", text: $text)
                    Picker("Status", selection: $selection) {
                        Text("All").tag("All")
                        Text("Reviewed").tag("Reviewed")
                    }
                }
                .padding()
                .frame(width: 400, height: 200)
            }
        }
        Settings {
            VStack(alignment: .leading, spacing: 24) {
                Text("Probe Settings").font(.title2)
                TextField("Name", text: $text).accessibilityLabel("Name")
                Text("Native settings window contrast diagnostic")
                Spacer()
            }.padding(30).frame(width: 550, height: 600)
        }
    }
}
