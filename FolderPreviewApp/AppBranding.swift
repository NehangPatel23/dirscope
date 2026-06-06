import AppKit
import SwiftUI

enum AppBranding {
    static let name = "Dirscope"
    static let tagline = "Inspect folder contents from Quick Look"
    static let extensionDisplayName = "Dirscope"
    static let accent = Color(red: 0.15, green: 0.72, blue: 0.65)
    static let accentSecondary = Color(red: 0.35, green: 0.38, blue: 0.85)

    /// Bundled app mark from the asset catalog — never the cached Dock icon.
    static var appMarkImage: NSImage {
        NSImage(named: "AppMark") ?? NSImage()
    }
}

enum VisualHeroStyle {
    /// Short, full-width strip — used on Extension, Appearance, Behaviors, etc.
    case compact
    /// Taller hero for the dashboard landing page.
    case featured
}
