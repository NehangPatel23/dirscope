import SwiftUI

struct QuickLookPageView: View {
    var body: some View {
        VisualPageScroll {
            VStack(spacing: 28) {
                VisualHeroBanner(
                    title: "Quick Look",
                    subtitle: "Use Dirscope anywhere Finder can preview a folder.",
                    systemImage: "eye.fill"
                )

                HStack(spacing: 16) {
                    VisualHighlightCard(
                        icon: "space",
                        tint: AppBranding.accent,
                        title: "Open from Finder",
                        subtitle: "Select a folder, press Space or ⌘Y",
                        delay: 0.05
                    )
                    VisualHighlightCard(
                        icon: "doc.zipper",
                        tint: AppBranding.accentSecondary,
                        title: "Archives too",
                        subtitle: "Zip, tar, gz, xz, 7z, and rar",
                        delay: 0.1
                    )
                    VisualHighlightCard(
                        icon: "doc.richtext",
                        tint: AppBranding.accent,
                        title: "File previews",
                        subtitle: "Read files in the side panel",
                        delay: 0.15
                    )
                }

                VisualGlassPanel(tint: AppBranding.accentSecondary, delay: 0.2) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("While previewing")
                            .font(.headline)

                        VisualTipRow(icon: "list.bullet", text: "Switch between List and Icons using the footer control.", delay: 0.22)
                        VisualTipRow(icon: "tablecells", text: "Control-click a column heading to show or hide list fields.", delay: 0.26)
                        VisualTipRow(icon: "chevron.down.circle", text: "Click the chevron beside a folder to expand nested contents.", delay: 0.3)
                        VisualTipRow(icon: "cursorarrow.click.2", text: "Double-click a file to open it in its default application.", delay: 0.34)
                    }
                }
            }
        }
    }
}
