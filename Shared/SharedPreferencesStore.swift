import Foundation

extension Notification.Name {
    static let previewSettingsDidChange = Notification.Name("com.dirscope.previewSettingsDidChange")
}

private let previewSettingsDarwinNotification = "com.dirscope.previewSettingsDidChange" as CFString

/// File-backed preferences shared by the Dirscope app and Quick Look extension.
///
/// Stored in the QL extension's sandbox container so the extension can read/write
/// without home-directory entitlements. The host app uses the same path explicitly.
final class SharedPreferencesStore {
    static let shared = SharedPreferencesStore()

    static let extensionBundleIdentifier = "com.folderpreview.app.preview"
    private static let preferencesFolderName = "Dirscope"
    private static let preferencesFileName = "Preferences.plist"

    static var isQuickLookExtension: Bool {
        Bundle.main.bundleURL.pathExtension == "appex"
    }

    static var fileURL: URL {
        preferencesDirectory.appendingPathComponent(preferencesFileName)
    }

    /// Shared prefs live in the extension container's Application Support folder.
    static var preferencesDirectory: URL {
        if isQuickLookExtension {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            return base.appendingPathComponent(preferencesFolderName, isDirectory: true)
        }

        return realUserHomeDirectory
            .appendingPathComponent(
                "Library/Containers/\(extensionBundleIdentifier)/Data/Library/Application Support/\(preferencesFolderName)",
                isDirectory: true
            )
    }

    private static var legacyHostPreferencesFileURL: URL {
        realUserHomeDirectory
            .appendingPathComponent("Library/Application Support/\(preferencesFolderName)/\(preferencesFileName)")
    }

    private static var realUserHomeDirectory: URL {
        let fileManager = FileManager.default
        let reportedHome = fileManager.homeDirectoryForCurrentUser
        if fileManager.fileExists(atPath: reportedHome.path) {
            return reportedHome
        }

        if let passwd = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: passwd.pointee.pw_dir), isDirectory: true)
        }

        return reportedHome
    }

    private let lock = NSLock()
    private var values: [String: Any]

    private init() {
        values = Self.loadInitialValues()
    }

    func reloadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        values = Self.loadFromDisk(at: Self.fileURL)
    }

    func object(forKey key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        lock.lock()
        if let value {
            values[key] = value
        } else {
            values.removeValue(forKey: key)
        }
        let snapshot = values
        lock.unlock()

        Self.writeToDisk(snapshot, at: Self.fileURL)
        Self.notifySettingsDidChange()
    }

    /// Fills missing keys in memory. Only the host app persists newly registered defaults.
    func registerDefaults(_ defaults: [String: Any]) {
        lock.lock()
        var changed = false
        for (key, value) in defaults where values[key] == nil {
            values[key] = value
            changed = true
        }
        let snapshot = values
        lock.unlock()

        if changed, !Self.isQuickLookExtension {
            Self.writeToDisk(snapshot, at: Self.fileURL)
        }
    }

    static func addDarwinObserver(_ handler: @escaping () -> Void) -> UnsafeMutableRawPointer {
        let token = UnsafeMutableRawPointer(Unmanaged.passRetained(DarwinObserverBox(handler)).toOpaque())
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            token,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let box = Unmanaged<DarwinObserverBox>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async(execute: box.handler)
            },
            previewSettingsDarwinNotification,
            nil,
            .deliverImmediately
        )
        return token
    }

    static func removeDarwinObserver(_ token: UnsafeMutableRawPointer) {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            token,
            CFNotificationName(previewSettingsDarwinNotification),
            nil
        )
        Unmanaged<DarwinObserverBox>.fromOpaque(token).release()
    }

    private static func notifySettingsDidChange() {
        NotificationCenter.default.post(name: .previewSettingsDidChange, object: nil)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(previewSettingsDarwinNotification),
            nil,
            nil,
            true
        )
    }

    private static func loadInitialValues() -> [String: Any] {
        let currentValues = loadFromDisk(at: fileURL)
        if !currentValues.isEmpty {
            return currentValues
        }

        let legacyValues = loadFromDisk(at: legacyHostPreferencesFileURL)
        if !legacyValues.isEmpty {
            writeToDisk(legacyValues, at: fileURL)
            return legacyValues
        }

        return [:]
    }

    private static func loadFromDisk(at url: URL) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return [:]
        }
        return plist
    }

    private static func writeToDisk(_ values: [String: Any], at url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let data = try? PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}

private final class DarwinObserverBox {
    let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }
}
