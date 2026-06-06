import Foundation

enum InlineFilePreviewLoader {
    private static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "yaml", "yml", "json", "swift", "py", "js", "ts",
        "jsx", "tsx", "html", "htm", "css", "scss", "sass", "less", "xml", "sh", "bash", "zsh",
        "fish", "env", "toml", "ini", "log", "csv", "sql", "rb", "go", "rs", "java",
        "kt", "kts", "c", "cpp", "cc", "cxx", "h", "hpp", "hh", "m", "mm", "plist",
        "dart", "php", "vue", "svelte", "lua", "r", "scala", "cs", "fs", "fsx", "zig",
        "nim", "ex", "exs", "erl", "hrl", "clj", "cljs", "groovy", "gradle", "tf",
        "tfvars", "proto", "graphql", "gql", "prisma", "nix", "v", "sv", "vhd", "vhdl",
        "asm", "s", "pas", "pp", "ada", "adb", "ads", "cmake", "xcconfig", "entitlements",
        "properties", "conf", "cfg", "cnf", "editorconfig", "gitignore", "gitattributes",
        "dockerignore", "mod", "sum", "lock", "sol", "wat", "wasm", "jl", "lisp", "el",
        "hs", "lhs", "ml", "mli", "f90", "f95", "f03", "vb", "vbs", "ps1", "psm1",
        "bat", "cmd", "reg", "rst", "tex", "bib", "sty", "cls", "jsonc", "json5",
        "http", "har", "patch", "diff", "map", "podspec", "modulemap", "swiftinterface",
        "strings", "xib", "storyboard", "pbxproj", "xcscheme", "xcworkspacedata"
    ]

    private static let maxPreviewBytes = 512_000

    static func isTextPreviewable(_ url: URL) -> Bool {
        isTextPreviewable(fileName: url.lastPathComponent)
    }

    static func isTextPreviewable(fileName: String) -> Bool {
        let lower = fileName.lowercased()
        let ext = URL(fileURLWithPath: lower).pathExtension
        if textExtensions.contains(ext) { return true }
        return lower == "dockerfile" || lower == "makefile" || lower.hasPrefix(".env")
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
            loaded = decodeText(from: data)
        }

        return loaded
    }

    static func decodeText(from data: Data) -> String? {
        if data.count > maxPreviewBytes {
            let prefix = data.prefix(maxPreviewBytes)
            let body = String(data: prefix, encoding: .utf8)
                ?? String(data: prefix, encoding: .ascii)
                ?? ""
            return body + "\n\n… Preview truncated …"
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
    }
}
