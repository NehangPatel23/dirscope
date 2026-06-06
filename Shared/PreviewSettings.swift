import Foundation

enum PreviewViewMode: String, CaseIterable, Identifiable {
    case list
    case icon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .icon: return "Icons"
        }
    }

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .icon: return "square.grid.2x2"
        }
    }
}

enum PreviewTextSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 12.5
        case .large: return 14
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .small: return 22
        case .medium: return 27
        case .large: return 32
        }
    }

    var thumbnailSize: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 36
        case .large: return 44
        }
    }

    var iconGridSize: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 96
        case .large: return 112
        }
    }
}

enum PreviewSettings {
    private static let store = SharedPreferencesStore.shared

    private static let preferenceKeys = [
        "viewMode", "textSize", "showThumbnails", "showPathBar",
        "showHiddenFiles", "keepFoldersOnTop", "expandChildFolders", "folderDepth",
        "iconZoom", "sortColumnID", "sortAscending", "visibleColumnIDs"
    ]

    /// Kept for SwiftUI `@AppStorage` compatibility in the host app.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: "com.dirscope.shared") ?? .standard
    }

    static func reloadFromDisk() {
        store.reloadFromDisk()
    }

    static var viewMode: PreviewViewMode {
        get { PreviewViewMode(rawValue: store.object(forKey: "viewMode") as? String ?? "") ?? .list }
        set { store.set(newValue.rawValue, forKey: "viewMode"); syncAppStorage(key: "viewMode", value: newValue.rawValue) }
    }

    static var textSize: PreviewTextSize {
        get {
            PreviewTextSize(rawValue: store.object(forKey: "textSize") as? String ?? "") ?? .small
        }
        set { store.set(newValue.rawValue, forKey: "textSize"); syncAppStorage(key: "textSize", value: newValue.rawValue) }
    }

    static var showThumbnails: Bool {
        get { store.object(forKey: "showThumbnails") as? Bool ?? true }
        set { store.set(newValue, forKey: "showThumbnails"); syncAppStorage(key: "showThumbnails", value: newValue) }
    }

    static var showPathBar: Bool {
        get { store.object(forKey: "showPathBar") as? Bool ?? true }
        set { store.set(newValue, forKey: "showPathBar"); syncAppStorage(key: "showPathBar", value: newValue) }
    }

    static var showHiddenFiles: Bool {
        get { store.object(forKey: "showHiddenFiles") as? Bool ?? false }
        set { store.set(newValue, forKey: "showHiddenFiles"); syncAppStorage(key: "showHiddenFiles", value: newValue) }
    }

    static var keepFoldersOnTop: Bool {
        get { store.object(forKey: "keepFoldersOnTop") as? Bool ?? true }
        set { store.set(newValue, forKey: "keepFoldersOnTop"); syncAppStorage(key: "keepFoldersOnTop", value: newValue) }
    }

    static var expandChildFolders: Bool {
        get { store.object(forKey: "expandChildFolders") as? Bool ?? false }
        set { store.set(newValue, forKey: "expandChildFolders"); syncAppStorage(key: "expandChildFolders", value: newValue) }
    }

    static var folderDepth: Int {
        get {
            let value = store.object(forKey: "folderDepth") as? Int ?? 0
            return value == 0 ? 1 : min(max(value, 1), 7)
        }
        set {
            let clamped = min(max(newValue, 1), 7)
            store.set(clamped, forKey: "folderDepth")
            syncAppStorage(key: "folderDepth", value: clamped)
        }
    }

    static var iconZoom: Double {
        get {
            let value = store.object(forKey: "iconZoom") as? Double ?? 0
            return value == 0 ? 1.0 : min(max(value, 0.6), 1.6)
        }
        set {
            let clamped = min(max(newValue, 0.6), 1.6)
            store.set(clamped, forKey: "iconZoom")
            syncAppStorage(key: "iconZoom", value: clamped)
        }
    }

    static var sortColumnID: String {
        get { store.object(forKey: "sortColumnID") as? String ?? PreviewColumn.name.rawValue }
        set { store.set(newValue, forKey: "sortColumnID"); syncAppStorage(key: "sortColumnID", value: newValue) }
    }

    static var sortAscending: Bool {
        get { store.object(forKey: "sortAscending") as? Bool ?? true }
        set { store.set(newValue, forKey: "sortAscending"); syncAppStorage(key: "sortAscending", value: newValue) }
    }

    static var visibleColumnIDs: [String] {
        get {
            store.object(forKey: "visibleColumnIDs") as? [String]
                ?? PreviewColumn.defaultVisible.map(\.rawValue)
        }
        set { store.set(newValue, forKey: "visibleColumnIDs"); syncAppStorage(key: "visibleColumnIDs", value: newValue) }
    }

    static func isColumnVisible(_ column: PreviewColumn) -> Bool {
        visibleColumnIDs.contains(column.rawValue)
    }

    static func setColumnVisible(_ column: PreviewColumn, visible: Bool) {
        var columns = visibleColumnIDs
        if visible {
            if !columns.contains(column.rawValue) { columns.append(column.rawValue) }
        } else {
            columns.removeAll { $0 == column.rawValue }
        }
        if !columns.contains(PreviewColumn.name.rawValue) {
            columns.insert(PreviewColumn.name.rawValue, at: 0)
        }
        visibleColumnIDs = columns
    }

    /// Applies default values in memory. Migration and disk writes happen only in the host app.
    static func registerDefaults() {
        if !SharedPreferencesStore.isQuickLookExtension {
            migrateLegacyPreferencesIfNeeded()
        }
        store.registerDefaults([
            "viewMode": PreviewViewMode.list.rawValue,
            "textSize": PreviewTextSize.small.rawValue,
            "showThumbnails": true,
            "showPathBar": true,
            "showHiddenFiles": false,
            "keepFoldersOnTop": true,
            "expandChildFolders": false,
            "folderDepth": 1,
            "iconZoom": 1.0,
            "sortColumnID": PreviewColumn.name.rawValue,
            "sortAscending": true,
            "visibleColumnIDs": PreviewColumn.defaultVisible.map(\.rawValue)
        ])
    }

    private static func syncAppStorage(key: String, value: Any) {
        sharedDefaults.set(value, forKey: key)
    }

    private static func migrateLegacyPreferencesIfNeeded() {
        guard store.object(forKey: "viewMode") == nil else { return }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacySources: [URL] = [
            home.appendingPathComponent("Library/Preferences/com.dirscope.shared.plist"),
            home.appendingPathComponent("Library/Application Support/Dirscope/Preferences.plist"),
            home.appendingPathComponent("Library/Containers/\(SharedPreferencesStore.extensionBundleIdentifier)/Data/Library/Preferences/com.dirscope.shared.plist")
        ]

        let legacyDefaults = UserDefaults(suiteName: "com.dirscope.shared")

        var imported: [String: Any] = [:]

        if legacyDefaults != nil {
            for key in preferenceKeys {
                if let value = legacyDefaults?.object(forKey: key) {
                    imported[key] = value
                }
            }
        }

        if imported.isEmpty {
            for legacyURL in legacySources {
                guard FileManager.default.fileExists(atPath: legacyURL.path),
                      let data = try? Data(contentsOf: legacyURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                    continue
                }
                for key in preferenceKeys {
                    if let value = plist[key], imported[key] == nil {
                        imported[key] = value
                    }
                }
                if !imported.isEmpty { break }
            }
        }

        if imported.isEmpty {
            for key in preferenceKeys {
                if let value = UserDefaults.standard.object(forKey: key) {
                    imported[key] = value
                }
            }
        }

        for (key, value) in imported where store.object(forKey: key) == nil {
            store.set(value, forKey: key)
        }
    }
}
