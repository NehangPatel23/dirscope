import AppKit
import Foundation

enum RichTextPreviewFormat: String {
    case markdown
    case html
    case svg

    static func format(for url: URL) -> RichTextPreviewFormat? {
        format(forFileName: url.lastPathComponent)
    }

    static func format(forFileName fileName: String) -> RichTextPreviewFormat? {
        let lower = fileName.lowercased()
        let ext = URL(fileURLWithPath: lower).pathExtension

        if !ext.isEmpty {
            switch ext {
            case "md", "markdown":
                return .markdown
            case "html", "htm":
                return .html
            case "svg":
                return .svg
            default:
                break
            }
        }

        return nil
    }

    var sourceLabel: String {
        switch self {
        case .markdown: return "Source"
        case .html, .svg: return "Source"
        }
    }

    var renderedLabel: String { "Formatted" }
}

enum FilePreviewDisplayMode: Int {
    case source = 0
    case rendered = 1
}

enum RichTextPreviewRenderer {
    static func renderedMarkdown(_ source: String, baseURL: URL) -> NSAttributedString? {
        if let roundTrip = markdownViaHTMLRoundTrip(source, baseURL: baseURL),
           hasDistinctBlocks(roundTrip) {
            return roundTrip
        }
        return markdownFromBlocks(source, baseURL: baseURL)
    }

    static func renderedHTML(_ source: String, baseURL: URL) -> NSAttributedString? {
        renderedHTMLDocument(source, baseURL: baseURL)
    }

    static func hasVisibleText(_ attributed: NSAttributedString) -> Bool {
        let plain = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return !plain.isEmpty
    }

    private static func markdownViaHTMLRoundTrip(_ source: String, baseURL: URL) -> NSAttributedString? {
        guard let markdown = try? NSAttributedString(
            markdown: Data(source.utf8),
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full),
            baseURL: baseURL
        ) else {
            return nil
        }

        let range = NSRange(location: 0, length: markdown.length)
        guard let htmlData = try? markdown.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ), let html = String(data: htmlData, encoding: .utf8) else {
            return normalizeForTextView(markdown)
        }
        return renderedHTMLDocument(html, baseURL: baseURL)
    }

    private static func markdownFromBlocks(_ source: String, baseURL: URL) -> NSAttributedString {
        let blocks = splitMarkdownBlocks(source)
        let result = NSMutableAttributedString()
        let separatorStyle = NSMutableParagraphStyle()
        separatorStyle.paragraphSpacing = 10

        for (index, block) in blocks.enumerated() {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if index > 0 {
                result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: separatorStyle]))
            }

            if let blockAttr = try? NSAttributedString(
                markdown: Data(trimmed.utf8),
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full),
                baseURL: baseURL
            ) {
                result.append(normalizeForTextView(blockAttr))
            } else {
                result.append(plainTextPreview(trimmed))
            }
        }

        return result.length > 0 ? result : plainTextPreview(source)
    }

    private static func splitMarkdownBlocks(_ source: String) -> [String] {
        var blocks: [String] = []
        var current = ""
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        for line in lines {
            let text = String(line)
            let isBlank = text.trimmingCharacters(in: .whitespaces).isEmpty
            let isBlockStart = text.hasPrefix("#")
                || text.hasPrefix("```")
                || text.hasPrefix(">")
                || text.hasPrefix("- ")
                || text.hasPrefix("* ")
                || text.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil

            if isBlank {
                if !current.isEmpty {
                    blocks.append(current)
                    current = ""
                }
                continue
            }

            if isBlockStart && !current.isEmpty {
                blocks.append(current)
                current = text
            } else if current.isEmpty {
                current = text
            } else {
                current += "\n" + text
            }
        }

        if !current.isEmpty {
            blocks.append(current)
        }

        return blocks.isEmpty ? [source] : blocks
    }

    private static func hasDistinctBlocks(_ attributed: NSAttributedString) -> Bool {
        var paragraphCount = 0
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            let text = (attributed.string as NSString).substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                paragraphCount += 1
            }
        }
        return paragraphCount > 1
    }

    private static func renderedHTMLDocument(_ html: String, baseURL: URL) -> NSAttributedString? {
        let wrapped = html.lowercased().contains("<html")
            ? html
            : """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8"></head><body>\(html)</body></html>
            """

        guard let data = wrapped.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return nil
        }
        return normalizeForTextView(attributed)
    }

    private static func plainTextPreview(_ source: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.paragraphSpacing = 8
        return NSAttributedString(
            string: source,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]
        )
    }

    private static func normalizeForTextView(_ attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)
        guard fullRange.length > 0 else { return attributed }

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let defaultStyle = NSMutableParagraphStyle()
        defaultStyle.lineSpacing = 2
        defaultStyle.paragraphSpacing = 8
        defaultStyle.paragraphSpacingBefore = 4
        defaultStyle.lineBreakMode = .byWordWrapping

        mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? defaultStyle.mutableCopy() as! NSMutableParagraphStyle
            style.lineSpacing = max(style.lineSpacing, 2)
            style.paragraphSpacing = max(style.paragraphSpacing, 8)
            style.paragraphSpacingBefore = max(style.paragraphSpacingBefore, 4)
            style.lineBreakMode = .byWordWrapping
            mutable.addAttribute(.paragraphStyle, value: style, range: range)
        }

        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if mutable.attribute(.link, at: range.location, effectiveRange: nil) != nil {
                return
            }

            guard let color = value as? NSColor, let rgb = color.usingColorSpace(.deviceRGB) else {
                mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                return
            }

            let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
            if isDark && luminance < 0.55 {
                mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            } else if !isDark && luminance > 0.75 {
                mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            }
        }

        var missingStyle = IndexSet()
        mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            if value == nil { missingStyle.insert(integersIn: range.location..<range.upperBound) }
        }
        if !missingStyle.isEmpty {
            mutable.addAttribute(.paragraphStyle, value: defaultStyle, range: fullRange)
        }

        return mutable
    }
}
