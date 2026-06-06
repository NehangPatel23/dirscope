import AppKit

enum FileIconCache {
    static let shared = Cache()

    final class Cache {
        private let cache = NSCache<NSString, NSImage>()

        init() {
            cache.countLimit = 500
        }

        func icon(for item: FileItem) -> NSImage {
            let key = item.id as NSString
            if let cached = cache.object(forKey: key) {
                return cached
            }

            let image: NSImage
            if item.isDirectory {
                image = NSWorkspace.shared.icon(for: .folder)
            } else if item.isBrowsableArchive {
                image = NSWorkspace.shared.icon(forFile: item.url.path)
            } else if item.isArchiveEntry {
                image = NSWorkspace.shared.icon(forFile: "/\(item.name)")
            } else {
                image = NSWorkspace.shared.icon(forFile: item.url.path)
            }

            cache.setObject(image, forKey: key)
            return image
        }

        func icon(for path: String) -> NSImage {
            let key = path as NSString
            if let cached = cache.object(forKey: key) {
                return cached
            }
            let image = NSWorkspace.shared.icon(forFile: path)
            cache.setObject(image, forKey: key)
            return image
        }
    }
}
