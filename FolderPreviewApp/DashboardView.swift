import SwiftUI

struct DashboardView: View {
    var body: some View {
        VisualPageScroll {
            VStack(spacing: 32) {
                VisualHeroBanner(
                    title: AppBranding.name,
                    subtitle: "Folder previews, built for Finder",
                    style: .featured,
                    showAppIcon: true,
                    showKeyCaps: true
                )

                HStack(spacing: 16) {
                    VisualHighlightCard(
                        icon: "folder.badge.gearshape",
                        tint: AppBranding.accent,
                        title: "Browse folders",
                        subtitle: "See files without opening a window",
                        delay: 0.05
                    )
                    VisualHighlightCard(
                        icon: "doc.zipper",
                        tint: AppBranding.accentSecondary,
                        title: "Open archives",
                        subtitle: "Zip, tar, 7z & more — no extracting",
                        delay: 0.12
                    )
                    VisualHighlightCard(
                        icon: "sidebar.right",
                        tint: AppBranding.accent,
                        title: "Preview files",
                        subtitle: "Read documents in the side panel",
                        delay: 0.19
                    )
                }

                VisualQuickStartFlow()
            }
        }
    }
}

#Preview {
    DashboardView()
        .frame(width: 820, height: 620)
}
