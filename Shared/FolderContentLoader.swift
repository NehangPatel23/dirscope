import Foundation

enum FolderContentLoader {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .creationDateKey,
        .contentAccessDateKey,
        .addedToDirectoryDateKey,
        .localizedTypeDescriptionKey
    ]

    /// Loads only the immediate children of a folder. Used for interactive tree expansion.
    static func loadImmediateChildren(of folderURL: URL) -> [FileItem] {
        loadSingleDirectory(folderURL.resolvingSymlinksInPath(), pathPrefix: "")
    }

    static func loadContents(of folderURL: URL) -> [FileItem] {
        let resolved = folderURL.resolvingSymlinksInPath()
        if PreviewSettings.expandChildFolders && PreviewSettings.folderDepth > 1 {
            return loadRecursive(
                folderURL: resolved,
                currentDepth: 1,
                maxDepth: PreviewSettings.folderDepth,
                pathPrefix: ""
            )
        }
        return loadSingleDirectory(resolved, pathPrefix: "")
    }

    static func sorted(_ items: [FileItem]) -> [FileItem] {
        guard let column = PreviewColumn(rawValue: PreviewSettings.sortColumnID),
              let sortColumn = PreviewSortColumn(previewColumn: column) else {
            return defaultSorted(items)
        }

        let ascending = PreviewSettings.sortAscending
        return items.sorted { lhs, rhs in
            let result = sortColumn.compare(lhs, rhs)
            if result == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private static func directoryOptions() -> FileManager.DirectoryEnumerationOptions {
        PreviewSettings.showHiddenFiles ? [] : [.skipsHiddenFiles]
    }

    private static func loadSingleDirectory(_ folderURL: URL, pathPrefix: String) -> [FileItem] {
        var items: [FileItem] = []
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            readingItemAt: folderURL,
            options: [.withoutChanges],
            error: &coordinatorError
        ) { readURL in
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: readURL,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: directoryOptions()
                )

                items = urls.compactMap { url -> FileItem? in
                    guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
                    let relative = pathPrefix.isEmpty ? url.lastPathComponent : "\(pathPrefix)/\(url.lastPathComponent)"
                    return FileItem.from(url: url, resourceValues: values, relativePath: relative)
                }
            } catch {}
        }

        return defaultSorted(items)
    }

    private static func loadRecursive(
        folderURL: URL,
        currentDepth: Int,
        maxDepth: Int,
        pathPrefix: String
    ) -> [FileItem] {
        var results: [FileItem] = []

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: directoryOptions()
            )

            for url in urls {
                guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
                let relative = pathPrefix.isEmpty ? url.lastPathComponent : "\(pathPrefix)/\(url.lastPathComponent)"
                let item = FileItem.from(url: url, resourceValues: values, relativePath: relative)
                results.append(item)

                if item.isDirectory, currentDepth < maxDepth {
                    results.append(contentsOf: loadRecursive(
                        folderURL: url,
                        currentDepth: currentDepth + 1,
                        maxDepth: maxDepth,
                        pathPrefix: relative
                    ))
                }
            }
        } catch {}

        return defaultSorted(results)
    }

    private static func defaultSorted(_ items: [FileItem]) -> [FileItem] {
        items.sorted { lhs, rhs in
            if PreviewSettings.keepFoldersOnTop, lhs.isContainer != rhs.isContainer {
                return lhs.isContainer && !rhs.isContainer
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
