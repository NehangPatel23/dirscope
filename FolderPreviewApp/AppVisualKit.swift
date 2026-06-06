import SwiftUI

// MARK: - Environment

private struct PageAppearedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PageDriftKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PageGlowKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var pageAppeared: Bool {
        get { self[PageAppearedKey.self] }
        set { self[PageAppearedKey.self] = newValue }
    }

    var pageDrift: Bool {
        get { self[PageDriftKey.self] }
        set { self[PageDriftKey.self] = newValue }
    }

    var pageGlow: Bool {
        get { self[PageGlowKey.self] }
        set { self[PageGlowKey.self] = newValue }
    }
}

// MARK: - Page shell

struct VisualPageScroll<Content: View>: View {
    var maxWidth: CGFloat = 820
    @ViewBuilder var content: Content

    @State private var appeared = false
    @State private var drift = false
    @State private var glow = false

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                PageAmbientBackground(drift: drift)

                content
                    .padding(AppTheme.contentPadding)
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.pageAppeared, appeared)
        .environment(\.pageDrift, drift)
        .environment(\.pageGlow, glow)
        .onAppear(perform: startAnimations)
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
            drift = true
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            glow = true
        }
    }
}

/// Full-height page shell without an outer scroll view — for settings that should fill the window.
struct VisualPageFill<Content: View>: View {
    var maxWidth: CGFloat = 820
    @ViewBuilder var content: Content

    @State private var appeared = false
    @State private var drift = false
    @State private var glow = false

    var body: some View {
        ZStack(alignment: .top) {
            PageAmbientBackground(drift: drift)

            content
                .padding(AppTheme.contentPadding)
                .frame(maxWidth: maxWidth, maxHeight: .infinity, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.pageAppeared, appeared)
        .environment(\.pageDrift, drift)
        .environment(\.pageGlow, glow)
        .onAppear(perform: startAnimations)
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
            drift = true
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            glow = true
        }
    }
}

struct PageAmbientBackground: View {
    let drift: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(AppBranding.accent.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: drift ? -140 : -100, y: drift ? -60 : -90)

            Circle()
                .fill(AppBranding.accentSecondary.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(x: drift ? 180 : 140, y: drift ? 120 : 80)

            Circle()
                .fill(AppBranding.accent.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 45)
                .offset(x: drift ? 40 : 70, y: drift ? 340 : 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - Heroes

struct VisualHeroBanner: View {
    let title: String
    let subtitle: String
    var style: VisualHeroStyle = .compact
    var systemImage: String? = nil
    var showAppIcon = false
    var showKeyCaps = false

    @Environment(\.pageAppeared) private var appeared
    @Environment(\.pageDrift) private var drift
    @Environment(\.pageGlow) private var glow

    private var appMarkSize: CGFloat { style == .compact ? 52 : 88 }
    private var iconBadgeSize: CGFloat { style == .compact ? 56 : 96 }
    private var symbolSize: CGFloat { style == .compact ? 24 : 30 }
    private var titleSize: CGFloat { style == .compact ? 26 : 32 }
    private var verticalPadding: CGFloat { style == .compact ? 18 : 28 }
    private var bannerHeight: CGFloat? { style == .compact ? 96 : nil }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppBranding.accent, AppBranding.accentSecondary],
                        startPoint: drift ? .topLeading : .leading,
                        endPoint: drift ? .bottomTrailing : .trailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(glow ? 0.22 : 0.12), .clear],
                                center: .topTrailing,
                                startRadius: 20,
                                endRadius: style == .compact ? 180 : 260
                            )
                        )
                }
                .shadow(color: AppBranding.accent.opacity(0.35), radius: glow ? 28 : 16, y: 12)

            HStack(spacing: style == .compact ? 18 : 24) {
                if showAppIcon {
                    AppMarkImage(size: appMarkSize)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                } else if let systemImage {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: iconBadgeSize, height: iconBadgeSize)
                        Image(systemName: systemImage)
                            .font(.system(size: symbolSize, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: style == .compact ? 4 : 8) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(style == .compact ? .subheadline.weight(.medium) : .body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(style == .compact ? 2 : nil)

                    if showKeyCaps {
                        HStack(spacing: 10) {
                            KeyCapLabel(title: "Space")
                            Text("or")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.75))
                            KeyCapLabel(title: "⌘Y")
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, verticalPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
        .fixedSize(horizontal: false, vertical: style == .featured)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

struct AppMarkImage: View {
    var size: CGFloat = 44

    var body: some View {
        Image(nsImage: AppBranding.appMarkImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

struct KeyCapLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.white.opacity(0.35), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Cards

struct VisualHighlightCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    var delay: Double = 0

    @Environment(\.pageAppeared) private var appeared
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(glassBackground)
        .overlay(glassBorder(tint: tint))
        .scaleEffect(hover ? 1.02 : 1)
        .shadow(color: tint.opacity(hover ? 0.18 : 0), radius: 12, y: 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(delay), value: appeared)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
    }
}

struct VisualStoryCard: View {
    let icon: String
    let tint: Color
    let title: String
    let message: String
    var delay: Double = 0

    @Environment(\.pageAppeared) private var appeared

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassBackground)
        .overlay(glassBorder(tint: tint))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(delay), value: appeared)
    }
}

struct VisualGlassPanel<Content: View>: View {
    var tint: Color = AppBranding.accent
    var delay: Double = 0
    @ViewBuilder var content: Content

    @Environment(\.pageAppeared) private var appeared

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassBackground)
            .overlay(glassBorder(tint: tint))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(delay), value: appeared)
    }
}

struct VisualStepRow: View {
    let number: Int
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    var delay: Double = 0

    @Environment(\.pageAppeared) private var appeared

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(tint))

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -12)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

struct VisualTipRow: View {
    let icon: String
    let text: String
    var delay: Double = 0

    @Environment(\.pageAppeared) private var appeared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppBranding.accent)
                .frame(width: 22)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }
}

struct VisualQuickStartFlow: View {
    @Environment(\.pageAppeared) private var appeared

    var body: some View {
        VStack(spacing: 20) {
            Text("Three steps to get going")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)

            HStack(spacing: 0) {
                flowStep(icon: "puzzlepiece.extension.fill", tint: AppBranding.accentSecondary, label: "Enable", detail: "Extension page", delay: 0.25)
                flowConnector(delay: 0.32)
                flowStep(icon: "hand.tap.fill", tint: AppBranding.accent, label: "Select", detail: "Any folder", delay: 0.35)
                flowConnector(delay: 0.42)
                flowStep(icon: "eye.fill", tint: AppBranding.accentSecondary, label: "Preview", detail: "Press Space", delay: 0.45)
            }
        }
        .padding(24)
        .background(glassBackground)
        .overlay(glassBorder(tint: AppBranding.accent))
    }

    private func flowStep(icon: String, tint: Color, label: String, detail: String, delay: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.14)).frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(spacing: 2) {
                Text(label).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85)
        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(delay), value: appeared)
    }

    private func flowConnector(delay: Double) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [AppBranding.accent.opacity(0.4), AppBranding.accentSecondary.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 36)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

struct VisualPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(AppBranding.accent)
    }
}

// MARK: - Shared styling

private var glassBackground: some View {
    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
}

private func glassBorder(tint: Color) -> some View {
    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        .stroke(tint.opacity(0.18), lineWidth: 1)
}
