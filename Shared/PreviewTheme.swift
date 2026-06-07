import AppKit

enum PreviewTheme {
    static var backgroundColor: NSColor { .windowBackgroundColor }
    static var secondaryBackground: NSColor { .controlBackgroundColor }
    static var separatorColor: NSColor { .separatorColor }
    static var accentColor: NSColor { .controlAccentColor }

    static var toolbarHeight: CGFloat { 48 }
    static var contentInset: CGFloat { 12 }
    static var cornerRadius: CGFloat { 8 }

    /// Horizontal inset per nesting level in the folder tree.
    static var treeIndentPerLevel: CGFloat { 28 }
    static var disclosureColumnWidth: CGFloat { 18 }

    static func treeIndent(for depth: Int) -> CGFloat {
        CGFloat(depth) * treeIndentPerLevel
    }

    static func nestedRowBackground(for depth: Int) -> NSColor {
        guard depth > 0 else { return .clear }
        return NSColor.controlBackgroundColor.withAlphaComponent(0.35 + min(CGFloat(depth) * 0.04, 0.2))
    }

    static func titleFont(size: PreviewTextSize) -> NSFont {
        .systemFont(ofSize: size.pointSize + 2, weight: .semibold)
    }

    static func bodyFont(size: PreviewTextSize) -> NSFont {
        .systemFont(ofSize: size.pointSize, weight: .regular)
    }

    static func captionFont(size: PreviewTextSize) -> NSFont {
        .systemFont(ofSize: max(size.pointSize - 1, 10), weight: .regular)
    }

    static func applyRoundedScrollStyle(_ scrollView: NSScrollView) {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.contentView.drawsBackground = false
    }

    /// Fills a view with `windowBackgroundColor`, refreshing when light/dark mode changes.
    static func applySurfaceBackground(to view: NSView) {
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        refreshSurfaceBackground(on: view)
    }

    static func refreshSurfaceBackground(on view: NSView) {
        view.layer?.backgroundColor = backgroundColor.cgColor
    }
}

enum PreviewLayout {
    /// Default Quick Look panel size — list + preview pane without manual resizing.
    static let defaultWidth: CGFloat = 1240
    static let defaultHeight: CGFloat = 720

    /// Right-hand file preview column (~36% of default width).
    static let previewPaneWidth: CGFloat = 440

    static var contentSize: NSSize {
        NSSize(width: defaultWidth, height: defaultHeight)
    }

    static var listPaneWidth: CGFloat {
        defaultWidth - previewPaneWidth - 1
    }

    static var footerZoneHeight: CGFloat {
        PreviewFooterView.totalHeight
    }
}
