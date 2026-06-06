import AppKit

enum FileItemLauncher {
    /// Opens a file or folder in its default application.
    /// Archive entries are staged in the shared container; the host app opens them when invoked from Quick Look.
    @discardableResult
    static func open(_ item: FileItem) -> Bool {
        if item.isArchiveEntry {
            guard !item.isContainer else { return false }

            guard let data = ArchiveContentLoader.extractEntryData(from: item.url, path: item.relativePath),
                  !data.isEmpty else {
                NSSound.beep()
                return false
            }

            guard let stagedURL = ArchiveEntryOpenBridge.stage(data: data, filename: item.name) else {
                NSSound.beep()
                return false
            }

            if SharedPreferencesStore.isQuickLookExtension {
                ArchiveEntryOpenBridge.requestHostOpen(stagedURL: stagedURL)
                return true
            }

            return ArchiveEntryOpenBridge.openStagedFile(at: stagedURL)
        }

        return NSWorkspace.shared.open(item.url)
    }
}
