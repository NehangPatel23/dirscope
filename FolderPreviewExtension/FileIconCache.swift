import AppKit

enum FileIconCache {
    static let shared = Cache()

    final class Cache {
        private let cache = NSCache<NSString, NSImage>()

        init() {
            cache.countLimit = 500
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
