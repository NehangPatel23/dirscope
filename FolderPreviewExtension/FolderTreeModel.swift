import Foundation

struct DisplayRow: Identifiable {
    let item: FileItem
    let depth: Int
    let isExpanded: Bool

    var id: String { item.id }
}

final class FolderTreeModel {
    private(set) var rootItems: [FileItem] = []
    private(set) var displayRows: [DisplayRow] = []

    private var expandedIDs: Set<String> = []
    private var childrenByID: [String: [FileItem]] = [:]

    private let maxExpandDepth = 7

    func setRootItems(_ items: [FileItem]) {
        rootItems = items
        expandedIDs.removeAll()
        childrenByID.removeAll()
        if PreviewSettings.expandChildFolders {
            autoExpandAll()
        }
        rebuildDisplayRows()
    }

    func isExpanded(_ itemID: String) -> Bool {
        expandedIDs.contains(itemID)
    }

    /// Synchronously toggles a folder. Returns the row index that changed, and inserted row range if expanded.
    @discardableResult
    func toggleFolder(itemID: String) -> (parentRow: Int, insertedRange: Range<Int>?)? {
        guard let parentRow = displayRows.firstIndex(where: { $0.item.id == itemID }) else { return nil }

        let row = displayRows[parentRow]
        guard row.item.isContainer else { return nil }

        if expandedIDs.contains(itemID) {
            collapse(itemID: itemID)
            rebuildDisplayRows()
            return (parentRow, nil)
        }

        guard row.depth < maxExpandDepth else { return nil }

        if childrenByID[itemID] == nil {
            let children = loadChildren(for: row.item)
            childrenByID[itemID] = children
        }

        let countBefore = displayRows.count
        expandedIDs.insert(itemID)
        rebuildDisplayRows()

        let countAfter = displayRows.count
        let inserted: Range<Int>? = countAfter > countBefore
            ? (parentRow + 1)..<(parentRow + 1 + (countAfter - countBefore))
            : nil
        return (parentRow, inserted)
    }

    func applySort() {
        rootItems = FolderContentLoader.sorted(rootItems)
        for id in Array(childrenByID.keys) {
            childrenByID[id] = FolderContentLoader.sorted(childrenByID[id] ?? [])
        }
        rebuildDisplayRows()
    }

    var allVisibleItems: [FileItem] {
        displayRows.map(\.item)
    }

    private func autoExpandAll() {
        func expandDirectories(_ items: [FileItem], depth: Int) {
            guard depth < PreviewSettings.folderDepth else { return }
            for item in items where item.isContainer {
                if childrenByID[item.id] == nil {
                    childrenByID[item.id] = loadChildren(for: item)
                }
                expandedIDs.insert(item.id)
                if let children = childrenByID[item.id] {
                    expandDirectories(children, depth: depth + 1)
                }
            }
        }
        expandDirectories(rootItems, depth: 0)
    }

    private func loadChildren(for item: FileItem) -> [FileItem] {
        let children: [FileItem]
        if item.isBrowsableArchive && item.isArchiveEntry {
            guard let nestedArchive = ArchiveContentLoader.extractEntryToTempFile(
                from: item.url,
                path: item.relativePath,
                filename: item.name
            ) else {
                return []
            }
            children = ArchiveContentLoader.loadContents(of: nestedArchive)
        } else if item.isArchiveEntry {
            children = ArchiveContentLoader.loadChildren(in: item.url, relativePath: item.relativePath)
        } else if item.isBrowsableArchive {
            children = ArchiveContentLoader.loadContents(of: item.url)
        } else {
            children = FolderContentLoader.loadImmediateChildren(of: item.url)
        }
        return FolderContentLoader.sorted(children)
    }

    private func collapse(itemID: String) {
        expandedIDs.remove(itemID)

        for id in Array(expandedIDs) where id.hasPrefix(itemID + "/") {
            expandedIDs.remove(id)
            childrenByID.removeValue(forKey: id)
        }
    }

    private func rebuildDisplayRows() {
        var rows: [DisplayRow] = []

        func appendItems(_ items: [FileItem], depth: Int) {
            for item in items {
                let expanded = item.isContainer && expandedIDs.contains(item.id)
                rows.append(DisplayRow(item: item, depth: depth, isExpanded: expanded))

                if expanded, let children = childrenByID[item.id] {
                    appendItems(children, depth: depth + 1)
                }
            }
        }

        appendItems(rootItems, depth: 0)
        displayRows = rows
    }
}
