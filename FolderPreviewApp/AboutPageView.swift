import SwiftUI

struct AboutPageView: View {
    var body: some View {
        VisualPageScroll(maxWidth: 640) {
            VStack(spacing: 28) {
                VisualHeroBanner(
                    title: AppBranding.name,
                    subtitle: "Quick Look folder viewer for macOS · Version 1.0",
                    style: .compact,
                    showAppIcon: true
                )

                HStack(spacing: 14) {
                    capabilityTile(icon: "folder.fill", tint: AppBranding.accent, title: "Directories", delay: 0.08)
                    capabilityTile(icon: "doc.zipper", tint: AppBranding.accentSecondary, title: "Archives", delay: 0.12)
                }

                HStack(spacing: 14) {
                    capabilityTile(icon: "doc.richtext", tint: AppBranding.accent, title: "File viewer", delay: 0.16)
                    capabilityTile(icon: "list.bullet.indent", tint: AppBranding.accentSecondary, title: "Folder tree", delay: 0.2)
                }

                VisualGlassPanel(tint: AppBranding.accent, delay: 0.24) {
                    VisualPrimaryButton(title: "Open Quick Look extension settings…", systemImage: "arrow.up.forward.app") {
                        ExtensionSettings.openQuickLookExtensions()
                    }
                }
            }
        }
    }

    private func capabilityTile(icon: String, tint: Color, title: String, delay: Double) -> some View {
        VisualHighlightCard(icon: icon, tint: tint, title: title, subtitle: "Included", delay: delay)
    }
}
