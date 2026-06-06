import SwiftUI

struct ContentView: View {
    @State private var selection: AppSection = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selection: $selection)

            Divider()

            Group {
                switch selection {
                case .dashboard:
                    DashboardView()
                case .introduction:
                    IntroductionView()
                case .quickLook:
                    QuickLookPageView()
                case .extensionSetup:
                    ExtensionPageView()
                case .appearance:
                    AppearancePageView()
                case .behaviors:
                    BehaviorsPageView()
                case .about:
                    AboutPageView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 820, minHeight: 560)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case introduction
    case quickLook
    case extensionSetup
    case appearance
    case behaviors
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .introduction: return "Introduction"
        case .quickLook: return "Quick Look"
        case .extensionSetup: return "Extension"
        case .appearance: return "Appearance"
        case .behaviors: return "Behaviors"
        case .about: return "About Dirscope"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .introduction: return "text.book.closed.fill"
        case .quickLook: return "eye.fill"
        case .extensionSetup: return "puzzlepiece.extension.fill"
        case .appearance: return "paintbrush.fill"
        case .behaviors: return "arrow.triangle.branch"
        case .about: return "info.circle.fill"
        }
    }
}

#Preview {
    ContentView()
}
