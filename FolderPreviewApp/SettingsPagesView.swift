import SwiftUI

struct AppearancePageView: View {
    var body: some View {
        VisualPageFill(maxWidth: 820) {
            VStack(spacing: 20) {
                VisualHeroBanner(
                    title: "Appearance",
                    subtitle: "Layout and panel options for Quick Look previews.",
                    style: .compact,
                    systemImage: "paintbrush.fill"
                )

                AppearanceSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct BehaviorsPageView: View {
    var body: some View {
        VisualPageFill(maxWidth: 820) {
            VStack(spacing: 20) {
                VisualHeroBanner(
                    title: "Behaviors",
                    subtitle: "How folder contents are listed and expanded.",
                    style: .compact,
                    systemImage: "arrow.triangle.branch"
                )

                BehaviorsSettingsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
