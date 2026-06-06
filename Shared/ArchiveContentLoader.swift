import Foundation

enum ArchiveContentLoader {
    static func isArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["zip", "tar", "gz", "tgz", "7z", "rar"].contains(ext)
    }

    static func loadContents(of archiveURL: URL) -> [FileItem] {
        let ext = archiveURL.pathExtension.lowercased()
        switch ext {
        case "zip":
            return loadZipContents(archiveURL)
        default:
            return []
        }
    }

    private static func loadZipContents(_ archiveURL: URL) -> [FileItem] {
        let entries = ZipEntryLister.listEntries(in: archiveURL)
        guard !entries.isEmpty else { return [] }

        var topLevelNames = Set<String>()
        var items: [FileItem] = []

        for entry in entries {
            let parts = entry.split(separator: "/").map(String.init)
            guard let first = parts.first else { continue }

            if parts.count == 1 {
                let isDir = entry.hasSuffix("/")
                let name = isDir ? String(first.dropLast()) : first
                guard !topLevelNames.contains(name) else { continue }
                topLevelNames.insert(name)
                items.append(makeArchiveItem(
                    archiveURL: archiveURL,
                    name: name,
                    relativePath: name,
                    isDirectory: isDir,
                    size: isDir ? nil : entrySize(entry, in: entries)
                ))
            } else if !topLevelNames.contains(first) {
                topLevelNames.insert(first)
                items.append(makeArchiveItem(
                    archiveURL: archiveURL,
                    name: first,
                    relativePath: first,
                    isDirectory: true,
                    size: nil
                ))
            }
        }

        return FolderContentLoader.sorted(items)
    }

    static func loadChildren(in archiveURL: URL, relativePath: String) -> [FileItem] {
        let entries = ZipEntryLister.listEntries(in: archiveURL)
        let prefix = relativePath.hasSuffix("/") ? relativePath : relativePath + "/"
        var childNames = Set<String>()
        var items: [FileItem] = []

        for entry in entries where entry.hasPrefix(prefix) {
            let remainder = String(entry.dropFirst(prefix.count))
            guard !remainder.isEmpty else { continue }
            let parts = remainder.split(separator: "/").map(String.init)
            guard let first = parts.first else { continue }

            if parts.count == 1 {
                let isDir = remainder.hasSuffix("/")
                let name = isDir ? String(first.dropLast()) : first
                guard !childNames.contains(name) else { continue }
                childNames.insert(name)
                let path = prefix + (isDir ? "\(name)/" : name)
                items.append(makeArchiveItem(
                    archiveURL: archiveURL,
                    name: name,
                    relativePath: path,
                    isDirectory: isDir,
                    size: isDir ? nil : entrySize(path, in: entries)
                ))
            } else if !childNames.contains(first) {
                childNames.insert(first)
                items.append(makeArchiveItem(
                    archiveURL: archiveURL,
                    name: first,
                    relativePath: prefix + first + "/",
                    isDirectory: true,
                    size: nil
                ))
            }
        }

        return FolderContentLoader.sorted(items)
    }

    private static func makeArchiveItem(
        archiveURL: URL,
        name: String,
        relativePath: String,
        isDirectory: Bool,
        size: Int64?
    ) -> FileItem {
        FileItem(
            url: archiveURL,
            name: name,
            isDirectory: isDirectory,
            size: size,
            modificationDate: nil,
            creationDate: nil,
            kind: isDirectory ? "Folder" : (URL(fileURLWithPath: name).pathExtension.isEmpty ? "Document" : "Archive Item"),
            relativePath: relativePath,
            isArchiveEntry: true
        )
    }

    private static func entrySize(_ entry: String, in entries: [String]) -> Int64? {
        entries.contains(entry) ? nil : nil
    }
}

enum ZipEntryLister {
    static func listEntries(in zipURL: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", zipURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output
                .split(separator: "\n")
                .map { String($0) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }
}
