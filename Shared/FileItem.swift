import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?
    let creationDate: Date?
    let contentAccessDate: Date?
    let addedToDirectoryDate: Date?
    let kind: String
    let relativePath: String
    let pixelWidth: Int?
    let pixelHeight: Int?
    let isArchiveEntry: Bool

    var id: String {
        isArchiveEntry ? "\(url.path)|\(relativePath)" : url.path
    }

    init(
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64?,
        modificationDate: Date?,
        creationDate: Date?,
        contentAccessDate: Date? = nil,
        addedToDirectoryDate: Date? = nil,
        kind: String,
        relativePath: String = "",
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        isArchiveEntry: Bool = false
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.contentAccessDate = contentAccessDate
        self.addedToDirectoryDate = addedToDirectoryDate
        self.kind = kind
        self.relativePath = relativePath.isEmpty ? name : relativePath
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isArchiveEntry = isArchiveEntry
    }

    var formattedSize: String {
        guard !isDirectory else { return "--" }
        guard let size else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDateModified: String { formatted(date: modificationDate) }
    var formattedDateCreated: String { formatted(date: creationDate) }
    var formattedDateLastOpened: String { formatted(date: contentAccessDate) }
    var formattedDateAdded: String { formatted(date: addedToDirectoryDate) }

    var formattedDimensions: String {
        guard let pixelWidth, let pixelHeight, pixelWidth > 0, pixelHeight > 0 else { return "--" }
        return "\(pixelWidth) × \(pixelHeight)"
    }

    var supportsThumbnail: Bool {
        guard !isDirectory, !isArchiveEntry else { return false }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
            || type.conforms(to: .pdf)
            || type.identifier == "public.svg-image"
    }

    func value(for column: PreviewColumn) -> String {
        switch column {
        case .preview: return ""
        case .name: return name
        case .dateModified: return formattedDateModified
        case .dateCreated: return formattedDateCreated
        case .dateLastOpened: return formattedDateLastOpened
        case .dateAdded: return formattedDateAdded
        case .size: return formattedSize
        case .kind: return kind
        case .dimensions: return formattedDimensions
        }
    }

    private func formatted(date: Date?) -> String {
        guard let date else { return "--" }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func from(url: URL, resourceValues: URLResourceValues, relativePath: String = "") -> FileItem {
        FileItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: resourceValues.isDirectory ?? false,
            size: resourceValues.fileSize.map { Int64($0) },
            modificationDate: resourceValues.contentModificationDate,
            creationDate: resourceValues.creationDate,
            contentAccessDate: resourceValues.contentAccessDate,
            addedToDirectoryDate: resourceValues.addedToDirectoryDate,
            kind: resourceValues.localizedTypeDescription ?? "Item",
            relativePath: relativePath.isEmpty ? url.lastPathComponent : relativePath
        )
    }
}

enum PreviewSortColumn: String {
    case name, dateModified, dateCreated, dateLastOpened, dateAdded, size, kind, dimensions

    init?(previewColumn: PreviewColumn) {
        switch previewColumn {
        case .name: self = .name
        case .dateModified: self = .dateModified
        case .dateCreated: self = .dateCreated
        case .dateLastOpened: self = .dateLastOpened
        case .dateAdded: self = .dateAdded
        case .size: self = .size
        case .kind: self = .kind
        case .dimensions: self = .dimensions
        case .preview: return nil
        }
    }

    func compare(_ lhs: FileItem, _ rhs: FileItem) -> ComparisonResult {
        if PreviewSettings.keepFoldersOnTop, lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory ? .orderedAscending : .orderedDescending
        }

        switch self {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .dateModified:
            return (lhs.modificationDate ?? .distantPast).compare(rhs.modificationDate ?? .distantPast)
        case .dateCreated:
            return (lhs.creationDate ?? .distantPast).compare(rhs.creationDate ?? .distantPast)
        case .dateLastOpened:
            return (lhs.contentAccessDate ?? .distantPast).compare(rhs.contentAccessDate ?? .distantPast)
        case .dateAdded:
            return (lhs.addedToDirectoryDate ?? .distantPast).compare(rhs.addedToDirectoryDate ?? .distantPast)
        case .size:
            let left = lhs.size ?? 0
            let right = rhs.size ?? 0
            if left == right { return .orderedSame }
            return left < right ? .orderedAscending : .orderedDescending
        case .kind:
            return lhs.kind.localizedStandardCompare(rhs.kind)
        case .dimensions:
            let left = (lhs.pixelWidth ?? 0) * (lhs.pixelHeight ?? 0)
            let right = (rhs.pixelWidth ?? 0) * (rhs.pixelHeight ?? 0)
            if left == right { return .orderedSame }
            return left < right ? .orderedAscending : .orderedDescending
        }
    }
}

enum FileItemSummary {
    static func totalSize(of items: [FileItem]) -> Int64 {
        items.reduce(0) { partial, item in
            partial + (item.isDirectory ? 0 : (item.size ?? 0))
        }
    }

    static func formattedTotalSize(of items: [FileItem]) -> String {
        ByteCountFormatter.string(fromByteCount: totalSize(of: items), countStyle: .file)
    }
}
