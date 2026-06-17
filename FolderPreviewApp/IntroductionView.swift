import SwiftUI

struct IntroductionView: View {
    var body: some View {
        VisualPageScroll {
            VStack(spacing: 28) {
                VisualHeroBanner(
                    title: "Meet Dirscope",
                    subtitle: "A friendlier way to peek inside folders from Finder.",
                    systemImage: "hand.wave.fill"
                )

                VisualStoryCard(
                    icon: "sparkles",
                    tint: AppBranding.accent,
                    title: "Welcome",
                    message: "Dirscope helps you explore folders without leaving Finder. Press Space on any folder and see what's inside — files, subfolders, and even compressed archives — right in Quick Look.",
                    delay: 0.05
                )

                VisualStoryCard(
                    icon: "questionmark.circle.fill",
                    tint: AppBranding.accentSecondary,
                    title: "Why it exists",
                    message: "Quick Look is handy for photos and documents, but folders usually stop at a plain icon. Dirscope fills that gap: a simple way to scan, sort, and preview folder contents the moment you need them, with no extra windows to manage.",
                    delay: 0.1
                )

                VisualStoryCard(
                    icon: "play.circle.fill",
                    tint: AppBranding.accent,
                    title: "How to get started",
                    message: "Turn on the Dirscope extension once — you'll find step-by-step instructions on the Extension page. After that, highlight a folder in Finder and press Space or ⌘Y. Browse the list, click a file to preview it on the right, and double-click anything to open it normally. Zip and tar archives expand in the list too; use Open on a file inside an archive to launch it in its default app.",
                    delay: 0.15
                )

                VisualStoryCard(
                    icon: "archivebox.fill",
                    tint: AppBranding.accentSecondary,
                    title: "Archives in Quick Look",
                    message: "Press Space on a .zip or .tar.gz file to browse its contents like a folder. Preview images, code, and HTML inside the archive without extracting it first. Files that need another app can be opened via the side panel — Dirscope uses a small background helper so Launch Services can reach them from the sandbox.",
                    delay: 0.175
                )

                VisualStoryCard(
                    icon: "slider.horizontal.3",
                    tint: AppBranding.accentSecondary,
                    title: "Make it feel like home",
                    message: "Visit Appearance and Behaviors in the sidebar to choose list or icon view, adjust text size, and set how folders expand. Your choices apply automatically the next time you use Quick Look.",
                    delay: 0.2
                )

                VisualGlassPanel(tint: AppBranding.accent, delay: 0.25) {
                    HStack(spacing: 12) {
                        Image(systemName: "sidebar.leading")
                            .font(.title2)
                            .foregroundStyle(AppBranding.accent)

                        Text("Use the sidebar anytime you want a walkthrough, setup help, or finer control.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
