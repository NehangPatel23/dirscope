import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private var cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(label: "com.folderpreview.thumbnails", qos: .userInitiated)

    private init() {
        cache.countLimit = 200
    }

    func thumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }

        queue.async {
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: size, height: size),
                scale: scale,
                representationTypes: .all
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                DispatchQueue.main.async {
                    if let cgImage = representation?.cgImage {
                        let image = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
                        self.cache.setObject(image, forKey: key)
                        completion(image)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    func cancelAll() {
        cache.removeAllObjects()
    }
}
