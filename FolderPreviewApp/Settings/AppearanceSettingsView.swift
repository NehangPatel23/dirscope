import SwiftUI

struct AppearanceSettingsView: View {
    @State private var viewMode = PreviewSettings.viewMode.rawValue
    @State private var textSize = PreviewSettings.textSize.rawValue
    @State private var showPathBar = PreviewSettings.showPathBar
    var body: some View {
        Form {
            Section("Layout") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Default view", selection: $viewMode) {
                        Text("List").tag(PreviewViewMode.list.rawValue)
                        Text("Icons").tag(PreviewViewMode.icon.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewMode) { PreviewSettings.viewMode = PreviewViewMode(rawValue: $0) ?? .list }

                    SettingHint("Starts each Quick Look session in list or icon view.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker("Text size", selection: $textSize) {
                        ForEach(PreviewTextSize.allCases) { size in
                            Text(size.title).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: textSize) { PreviewSettings.textSize = PreviewTextSize(rawValue: $0) ?? .small }

                    SettingHint("Makes rows, labels, and icons larger or smaller throughout the preview.")
                }
            }

            Section("Chrome") {
                Toggle(isOn: $showPathBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show path breadcrumb")
                        SettingHint("Displays the current folder path above the status bar.")
                    }
                }
                .onChange(of: showPathBar) { PreviewSettings.showPathBar = $0 }
            }

            Section {
                Text("Right-click any column header in the preview to show or hide metadata columns.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        viewMode = PreviewSettings.viewMode.rawValue
        textSize = PreviewSettings.textSize.rawValue
        showPathBar = PreviewSettings.showPathBar
    }
}

#Preview {
    AppearanceSettingsView()
        .padding()
}
