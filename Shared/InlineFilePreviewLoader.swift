import Foundation

enum InlineFilePreviewLoader {
    private static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "yaml", "yml", "json", "swift", "py", "js", "ts",
        "jsx", "tsx", "html", "htm", "css", "scss", "xml", "sh", "bash", "zsh",
        "env", "toml", "ini", "log", "csv", "sql", "rb", "go", "rs", "java",
        "kt", "c", "cpp", "h", "hpp", "m", "mm", "plist", "dockerfile", "makefile"
    ]

    private static let maxPreviewBytes = 512_000

    static func isTextPreviewable(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if textExtensions.contains(ext) { return true }
        let name = url.lastPathComponent.lowercased()
        return name == "dockerfile" || name == "makefile" || name.hasPrefix(".env")
    }

    static func loadText(from url: URL) -> String? {
        var loaded: String?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            readingItemAt: url,
            options: [.withoutChanges],
            error: &coordinatorError
        ) { readURL in
            guard let data = try? Data(contentsOf: readURL, options: [.mappedIfSafe]) else { return }
            if data.count > maxPreviewBytes {
                let prefix = data.prefix(maxPreviewBytes)
                let body = String(data: prefix, encoding: .utf8)
                    ?? String(data: prefix, encoding: .ascii)
                    ?? ""
                loaded = body + "\n\n… Preview truncated …"
                return
            }
            loaded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        }

        return loaded
    }
}
