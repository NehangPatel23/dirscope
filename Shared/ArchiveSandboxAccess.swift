import Foundation

enum ArchiveSandboxAccess {
    private struct ArchiveCacheKey: Hashable {
        let path: String
        let fileSize: Int64?
        let modificationDate: TimeInterval?
    }

    private static var tempCopies: [String: URL] = [:]
    private static var dataCache: [ArchiveCacheKey: Data] = [:]
    private static let cacheLock = NSLock()
    private static let tempDirectory: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirscopeArchives", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func readData(from url: URL) -> Data? {
        let cacheKey = archiveCacheKey(for: url)

        cacheLock.lock()
        if let cached = dataCache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        var result: Data?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            readingItemAt: url,
            options: [.withoutChanges],
            error: &coordinatorError
        ) { readURL in
            result = try? Data(contentsOf: readURL, options: [.mappedIfSafe])
        }

        if result == nil {
            result = try? Data(contentsOf: url, options: [.mappedIfSafe])
        }

        if let result {
            cacheLock.lock()
            dataCache[cacheKey] = result
            cacheLock.unlock()
        }

        return result
    }

    /// Copies the archive into the extension container so sandboxed helper tools can read it.
    static func localReadableCopy(of url: URL) -> URL? {
        let key = url.standardizedFileURL.path
        if let cached = tempCopies[key], FileManager.default.isReadableFile(atPath: cached.path) {
            return cached
        }

        guard let data = readData(from: url) else { return nil }

        let destination = tempDirectory.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
        do {
            try data.write(to: destination, options: .atomic)
            tempCopies[key] = destination
            return destination
        } catch {
            return nil
        }
    }

    private static func archiveCacheKey(for url: URL) -> ArchiveCacheKey {
        let standardized = url.standardizedFileURL
        let values = try? standardized.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return ArchiveCacheKey(
            path: standardized.path,
            fileSize: values?.fileSize.map { Int64($0) },
            modificationDate: values?.contentModificationDate?.timeIntervalSince1970
        )
    }
}
