import SwiftUI

struct AppSidebar: View {
    @Binding var selection: AppSection

    var body: some View {
        List(selection: $selection) {
            Section("Start") {
                ForEach([AppSection.dashboard, .introduction, .quickLook]) { section in
                    sidebarLabel(section)
                }
            }

            Section("Configure") {
                ForEach([AppSection.extensionSetup, .appearance, .behaviors]) { section in
                    sidebarLabel(section)
                }
            }

            Section {
                sidebarLabel(.about)
            }
        }
        .listStyle(.sidebar)
        .frame(width: AppTheme.sidebarWidth)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sidebarLabel(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
    }
}
