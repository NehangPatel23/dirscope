import SwiftUI

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("What's included") {
                Label("Directory browsing", systemImage: "folder")
                Label("Compressed archives", systemImage: "doc.zipper")
                Label("Side-panel file viewer", systemImage: "doc.richtext")
                Label("Nested folder tree", systemImage: "list.bullet.indent")
            }

            Section {
                Button("Open Quick Look extension settings…") {
                    ExtensionSettings.openQuickLookExtensions()
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    GeneralSettingsView()
        .padding()
}
