import SwiftUI

/// macOS Settings window (⌘,) — mirrors in-app Appearance and Behaviors pages.
struct SettingsView: View {
    var body: some View {
        VisualPageFill(maxWidth: 820) {
            VStack(spacing: 20) {
                VisualHeroBanner(
                    title: "Settings",
                    subtitle: "Appearance and browsing preferences.",
                    style: .compact,
                    systemImage: "gearshape.fill"
                )

                AppearanceSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                BehaviorsSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 640, height: 680)
    }
}

#Preview {
    SettingsView()
}
