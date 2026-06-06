import AppKit
import QuickLookUI

final class FilePreviewPaneView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let modeControl = NSSegmentedControl()
    private let topSeparator = NSBox()
    private let contentContainer = NSView()

    private var qlPreviewView: QLPreviewView?
    private let sourceScrollView = NSScrollView()
    private let sourceTextView = NSTextView()
    private let renderedScrollView = NSScrollView()
    private let renderedTextView = NSTextView()
    private let svgImageView = NSImageView()
    private let placeholderView = PreviewPlaceholderView()

    private var currentItem: FileItem?
    private var currentSourceText: String?
    private var currentRichFormat: RichTextPreviewFormat?
    private var displayMode: FilePreviewDisplayMode = .source

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func show(item: FileItem?) {
        currentItem = item
        currentSourceText = nil
        currentRichFormat = nil
        modeControl.isHidden = true

        guard let item else {
            showPlaceholder(message: "Click a file in the list to inspect it here.")
            return
        }

        titleLabel.stringValue = item.name
        subtitleLabel.stringValue = item.isDirectory ? "Directory" : item.kind

        if item.isDirectory {
            placeholderView.configure(
                icon: NSImage(named: NSImage.folderName),
                title: item.name,
                message: "Use the disclosure arrow in the list to open this directory."
            )
            showPlaceholderMode()
            return
        }

        if item.isArchiveEntry {
            placeholderView.configure(
                icon: NSImage(systemSymbolName: "doc.zipper", accessibilityDescription: nil),
                title: item.name,
                message: "Unpack the archive to view this file."
            )
            showPlaceholderMode()
            return
        }

        if InlineFilePreviewLoader.isTextPreviewable(item.url),
           let text = InlineFilePreviewLoader.loadText(from: item.url) {
            showRichOrPlainText(text, for: item)
            return
        }

        if showQuickLookPreview(for: item.url) {
            return
        }

        placeholderView.configure(
            icon: FileIconCache.shared.icon(for: item.url.path),
            title: item.name,
            message: "Double-click to launch in its default application."
        )
        showPlaceholderMode()
    }

    private func showRichOrPlainText(_ text: String, for item: FileItem) {
        currentSourceText = text
        currentRichFormat = RichTextPreviewFormat.format(for: item.url)

        if currentRichFormat != nil {
            modeControl.isHidden = false
            modeControl.setLabel(currentRichFormat!.sourceLabel, forSegment: 0)
            modeControl.setLabel(currentRichFormat!.renderedLabel, forSegment: 1)
            displayMode = .rendered
            modeControl.selectedSegment = displayMode.rawValue
        } else {
            displayMode = .source
        }

        applyDisplayMode()
    }

    private func applyDisplayMode() {
        guard let text = currentSourceText, let item = currentItem else { return }

        if let format = currentRichFormat {
            switch displayMode {
            case .source:
                showSourceText(text)
            case .rendered:
                showRenderedPreview(for: item, format: format, source: text)
            }
            return
        }

        showSourceText(text)
    }

    private func showRenderedPreview(for item: FileItem, format: RichTextPreviewFormat, source: String) {
        let parentDirectory = item.url.deletingLastPathComponent()

        switch format {
        case .markdown:
            if let attributed = RichTextPreviewRenderer.renderedMarkdown(source, baseURL: parentDirectory) {
                showRenderedAttributedText(attributed)
            } else {
                showSourceText(source)
            }

        case .html:
            showHTMLPreview(for: item, source: source, baseURL: parentDirectory)

        case .svg:
            showSVGPreview(for: item.url, source: source)
        }
    }

    private func showHTMLPreview(for item: FileItem, source: String, baseURL: URL) {
        if let attributed = RichTextPreviewRenderer.renderedHTML(source, baseURL: baseURL),
           RichTextPreviewRenderer.hasVisibleText(attributed) {
            showRenderedAttributedText(attributed)
            return
        }

        placeholderView.configure(
            icon: NSImage(systemSymbolName: "globe", accessibilityDescription: nil),
            title: item.name,
            message: "This page needs a web browser to display. Switch to Source to read the markup, or double-click to open it externally."
        )
        hideAllContentViews()
        placeholderView.isHidden = false
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = PreviewTheme.secondaryBackground.withAlphaComponent(0.35).cgColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.textColor = .labelColor

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        modeControl.segmentCount = 2
        modeControl.segmentStyle = .automatic
        modeControl.trackingMode = .selectOne
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        modeControl.isHidden = true

        topSeparator.boxType = .separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        configureSourceTextScroll(sourceScrollView, textView: sourceTextView)
        configureRenderedTextScroll(renderedScrollView, textView: renderedTextView)

        svgImageView.translatesAutoresizingMaskIntoConstraints = false
        svgImageView.imageScaling = .scaleProportionallyUpOrDown
        svgImageView.imageAlignment = .alignCenter

        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(modeControl)
        addSubview(subtitleLabel)
        addSubview(topSeparator)
        addSubview(contentContainer)
        contentContainer.addSubview(sourceScrollView)
        contentContainer.addSubview(renderedScrollView)
        contentContainer.addSubview(svgImageView)
        contentContainer.addSubview(placeholderView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: modeControl.leadingAnchor, constant: -8),

            modeControl.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            modeControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            modeControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            topSeparator.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),

            contentContainer.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            sourceScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            sourceScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            sourceScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            sourceScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            renderedScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            renderedScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            renderedScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            renderedScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            svgImageView.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 12),
            svgImageView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 12),
            svgImageView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -12),
            svgImageView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -12),

            placeholderView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        if let preview = QLPreviewView(frame: .zero, style: .normal) {
            preview.translatesAutoresizingMaskIntoConstraints = false
            preview.autostarts = true
            qlPreviewView = preview
            contentContainer.addSubview(preview)
            NSLayoutConstraint.activate([
                preview.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                preview.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                preview.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                preview.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])
            preview.isHidden = true
        }

        showPlaceholder(message: "Click a file in the list to inspect it here.")
    }

    private func configureSourceTextScroll(_ scrollView: NSScrollView, textView: NSTextView) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
    }

    private func configureRenderedTextScroll(_ scrollView: NSScrollView, textView: NSTextView) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping
        scrollView.documentView = textView
    }

    @objc private func modeChanged() {
        guard modeControl.selectedSegment >= 0,
              let mode = FilePreviewDisplayMode(rawValue: modeControl.selectedSegment) else { return }
        displayMode = mode
        applyDisplayMode()
    }

    @discardableResult
    private func showQuickLookPreview(for url: URL) -> Bool {
        guard let qlPreviewView else { return false }
        hideAllContentViews()
        qlPreviewView.isHidden = false
        qlPreviewView.previewItem = url as NSURL
        qlPreviewView.refreshPreviewItem()
        return true
    }

    private func showRenderedAttributedText(_ attributed: NSAttributedString) {
        hideAllContentViews()
        renderedScrollView.isHidden = false
        renderedTextView.textStorage?.setAttributedString(attributed)
        renderedTextView.layoutManager?.ensureLayout(for: renderedTextView.textContainer!)
        renderedTextView.scrollToBeginningOfDocument(nil)
    }

    private func showSVGPreview(for url: URL, source: String) {
        hideAllContentViews()
        svgImageView.isHidden = false

        if let image = NSImage(contentsOf: url) {
            svgImageView.image = image
            return
        }

        if let data = source.data(using: .utf8), let image = NSImage(data: data) {
            svgImageView.image = image
            return
        }

        placeholderView.configure(
            icon: NSImage(systemSymbolName: "photo", accessibilityDescription: nil),
            title: url.lastPathComponent,
            message: "Unable to display this SVG."
        )
        svgImageView.isHidden = true
        placeholderView.isHidden = false
    }

    private func showSourceText(_ text: String) {
        hideAllContentViews()
        sourceScrollView.isHidden = false
        sourceTextView.string = text
        sourceTextView.scrollToBeginningOfDocument(nil)
    }

    private func hideAllContentViews() {
        sourceScrollView.isHidden = true
        renderedScrollView.isHidden = true
        svgImageView.isHidden = true
        qlPreviewView?.isHidden = true
        placeholderView.isHidden = true
    }

    private func showPlaceholder(message: String) {
        titleLabel.stringValue = "Inspect"
        subtitleLabel.stringValue = ""
        modeControl.isHidden = true
        placeholderView.configure(
            icon: NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: nil),
            title: "Nothing selected",
            message: message
        )
        hideAllContentViews()
        placeholderView.isHidden = false
    }

    private func showPlaceholderMode() {
        modeControl.isHidden = true
        hideAllContentViews()
        placeholderView.isHidden = false
    }
}

private final class PreviewPlaceholderView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingMiddle

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 11)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .center

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -28),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: NSImage?, title: String, message: String) {
        iconView.image = icon
        titleLabel.stringValue = title
        messageLabel.stringValue = message
    }
}
