import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private var cache = NSCache<NSURL, NSImage>()
    private var archiveCache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.folderpreview.thumbnails", qos: .userInitiated)

    private init() {
        cache.countLimit = 200
        archiveCache.countLimit = 200
    }

    func cachedThumbnail(for item: FileItem, size: CGFloat) -> NSImage? {
        if item.isArchiveEntry {
            return archiveCache.object(forKey: item.id as NSString)
        }
        return cache.object(forKey: item.url as NSURL)
    }

    func thumbnail(for item: FileItem, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        guard item.supportsThumbnail else {
            completion(nil)
            return
        }

        if let cached = cachedThumbnail(for: item, size: size) {
            completion(cached)
            return
        }

        if item.isArchiveEntry {
            thumbnailForArchiveEntry(item, size: size, completion: completion)
            return
        }

        thumbnail(for: item.url, size: size, completion: completion)
    }

    func thumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        queue.async {
            self.generateThumbnail(at: url, size: size) { image in
                DispatchQueue.main.async {
                    if let image {
                        self.cache.setObject(image, forKey: key)
                    }
                    completion(image)
                }
            }
        }
    }

    func cancelAll() {
        cache.removeAllObjects()
        archiveCache.removeAllObjects()
    }

    private func thumbnailForArchiveEntry(
        _ item: FileItem,
        size: CGFloat,
        completion: @escaping (NSImage?) -> Void
    ) {
        let key = item.id as NSString

        queue.async {
            let ext = URL(fileURLWithPath: item.name).pathExtension.lowercased()
            if let type = UTType(filenameExtension: ext), type.conforms(to: .image),
               let data = ArchiveContentLoader.extractEntryData(from: item.url, path: item.relativePath),
               !data.isEmpty,
               let source = NSImage(data: data) {
                let image = self.scaledImage(source, to: size)
                DispatchQueue.main.async {
                    self.archiveCache.setObject(image, forKey: key)
                    completion(image)
                }
                return
            }

            guard let tempURL = ArchiveContentLoader.extractEntryToTempFile(
                from: item.url,
                path: item.relativePath,
                filename: item.name
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.generateThumbnail(at: tempURL, size: size) { image in
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    if let image {
                        self.archiveCache.setObject(image, forKey: key)
                    }
                    completion(image)
                }
            }
        }
    }

    private func generateThumbnail(at url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let cgImage = representation?.cgImage else {
                completion(nil)
                return
            }
            completion(NSImage(cgImage: cgImage, size: NSSize(width: size, height: size)))
        }
    }

    private func scaledImage(_ image: NSImage, to size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let scaled = NSImage(size: target)
        scaled.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        scaled.unlockFocus()
        return scaled
    }
}
