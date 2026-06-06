import SwiftUI

struct BehaviorsSettingsView: View {
    @State private var showHiddenFiles = PreviewSettings.showHiddenFiles
    @State private var keepFoldersOnTop = PreviewSettings.keepFoldersOnTop
    @State private var expandChildFolders = PreviewSettings.expandChildFolders
    @State private var folderDepth = PreviewSettings.folderDepth

    var body: some View {
        Form {
            Section("Listing") {
                Toggle(isOn: $showHiddenFiles) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include hidden items")
                        SettingHint("Shows files and folders whose names begin with a period.")
                    }
                }
                .onChange(of: showHiddenFiles) { PreviewSettings.showHiddenFiles = $0 }

                Toggle(isOn: $keepFoldersOnTop) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sort folders first")
                        SettingHint("Keeps directories grouped above regular files when sorting.")
                    }
                }
                .onChange(of: keepFoldersOnTop) { PreviewSettings.keepFoldersOnTop = $0 }

                Toggle(isOn: $expandChildFolders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-expand subfolders")
                        SettingHint("Opens nested folders automatically so you can browse deeper levels inline.")
                    }
                }
                .onChange(of: expandChildFolders) { PreviewSettings.expandChildFolders = $0 }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: $folderDepth, in: 1...7) {
                        HStack {
                            Text("Maximum nesting depth")
                            Spacer()
                            Text("\(folderDepth)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onChange(of: folderDepth) { PreviewSettings.folderDepth = $0 }

                    SettingHint("Limits how many folder levels Dirscope expands inside the preview.")
                }
            } footer: {
                Text("Higher values reveal deeper folder trees but may take longer to load in very large directories.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .previewSettingsDidChange)) { _ in
            reloadFromStore()
        }
        .onAppear { reloadFromStore() }
    }

    private func reloadFromStore() {
        PreviewSettings.reloadFromDisk()
        showHiddenFiles = PreviewSettings.showHiddenFiles
        keepFoldersOnTop = PreviewSettings.keepFoldersOnTop
        expandChildFolders = PreviewSettings.expandChildFolders
        folderDepth = PreviewSettings.folderDepth
    }
}

#Preview {
    BehaviorsSettingsView()
        .padding()
}
