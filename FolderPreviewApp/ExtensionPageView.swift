import SwiftUI

struct ExtensionPageView: View {
    var body: some View {
        VisualPageScroll {
            VStack(spacing: 28) {
                VisualHeroBanner(
                    title: "Extension",
                    subtitle: "Enable Dirscope once in System Settings.",
                    systemImage: "puzzlepiece.extension.fill"
                )

                VisualGlassPanel(tint: AppBranding.accent, delay: 0.05) {
                    VStack(alignment: .leading, spacing: 20) {
                        VisualStepRow(
                            number: 1,
                            icon: "gearshape.fill",
                            tint: AppBranding.accent,
                            title: "Go to System Settings",
                            detail: "Open General → Login Items & Extensions, then choose Quick Look.",
                            delay: 0.08
                        )
                        VisualStepRow(
                            number: 2,
                            icon: "switch.2",
                            tint: AppBranding.accentSecondary,
                            title: "Activate Dirscope",
                            detail: "Switch on \(AppBranding.extensionDisplayName) so Finder can use it.",
                            delay: 0.12
                        )
                        VisualStepRow(
                            number: 3,
                            icon: "paintbrush.fill",
                            tint: AppBranding.accent,
                            title: "Adjust Appearance and Behaviors",
                            detail: "Set your default layout, text size, and folder listing rules.",
                            delay: 0.16
                        )

                        VisualPrimaryButton(title: "Open System Settings", systemImage: "arrow.up.forward.app") {
                            ExtensionSettings.openQuickLookExtensions()
                        }
                        .padding(.top, 4)
                    }
                }

                VisualGlassPanel(tint: AppBranding.accentSecondary, delay: 0.2) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppBranding.accentSecondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("After enabling")
                                .font(.headline)
                            Text("If Quick Look still shows the default folder preview, close the panel and try again. macOS may need a moment to register the new extension.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
