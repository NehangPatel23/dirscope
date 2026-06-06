import Foundation

enum PreviewColumn: String, CaseIterable, Identifiable {
    case preview
    case name
    case dateModified
    case dateCreated
    case dateLastOpened
    case dateAdded
    case size
    case kind
    case dimensions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: return "Preview"
        case .name: return "Name"
        case .dateModified: return "Modified"
        case .dateCreated: return "Created"
        case .dateLastOpened: return "Last Opened"
        case .dateAdded: return "Added"
        case .size: return "Size"
        case .kind: return "Type"
        case .dimensions: return "Resolution"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .preview: return 52
        case .name: return 240
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: return 148
        case .size: return 80
        case .kind: return 120
        case .dimensions: return 110
        }
    }

    var isOptional: Bool { self != .name }

    static let defaultVisible: [PreviewColumn] = [.name, .dateModified, .size, .kind]

    static var toggleable: [PreviewColumn] { allCases.filter { $0.isOptional && $0 != .preview } }
}
