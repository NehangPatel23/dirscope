import AppKit
import ImageIO
import QuickLookUI
import UniformTypeIdentifiers

final class FilePreviewPaneView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let modeControl = NSSegmentedControl()
    private let openButton = NSButton(title: "Open", target: nil, action: nil)
    private let topSeparator = NSBox()
    private let contentContainer = NSView()

    private var qlPreviewView: QLPreviewView?
    private let sourceScrollView = NSScrollView()
    private let sourceTextView = NSTextView()
    private let renderedScrollView = NSScrollView()
    private let renderedTextView = NSTextView()
    private let imageScrollView = NSScrollView()
    private let imagePreviewView = NSImageView()
    private let svgImageView = NSImageView()
    private let placeholderView = PreviewPlaceholderView()

    private var currentItem: FileItem?
    private var currentSourceText: String?
    private var currentRichFormat: RichTextPreviewFormat?
    private var displayMode: FilePreviewDisplayMode = .source
    private var extractedTempURL: URL?
    private var archiveEntryData: Data?
    private var archiveLoadToken: UUID?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func show(item: FileItem?) {
        cleanupExtractedTempFile()
        archiveEntryData = nil
        archiveLoadToken = nil
        currentItem = item
        currentSourceText = nil
        currentRichFormat = nil
        modeControl.isHidden = true
        updateOpenButton(for: item)

        guard let item else {
            showPlaceholder(message: "Click a file in the list to inspect it here.")
            return
        }

        titleLabel.stringValue = item.name
        subtitleLabel.stringValue = item.isDirectory ? "Directory" : (item.isBrowsableArchive ? "Archive" : item.kind)

        if item.isDirectory {
            placeholderView.configure(
                icon: NSImage(named: NSImage.folderName),
                title: item.name,
                message: "Use the disclosure arrow in the list to open this directory."
            )
            showPlaceholderMode()
            return
        }

        if item.isBrowsableArchive && !item.isArchiveEntry {
            placeholderView.configure(
                icon: NSImage(systemSymbolName: "doc.zipper", accessibilityDescription: nil),
                title: item.name,
                message: "Use the disclosure arrow in the list to browse this archive."
            )
            showPlaceholderMode()
            return
        }

        if item.isArchiveEntry {
            showArchiveEntryPreview(for: item)
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
            icon: FileIconCache.shared.icon(for: item),
            title: item.name,
            message: "Double-click to launch in its default application."
        )
        showPlaceholderMode()
    }

    private func showArchiveEntryPreview(for item: FileItem) {
        let token = UUID()
        archiveLoadToken = token

        placeholderView.configure(
            icon: FileIconCache.shared.icon(for: item),
            title: item.name,
            message: "Loading preview…"
        )
        showPlaceholderMode()

        let archiveURL = item.url
        let relativePath = item.relativePath
        let itemID = item.id

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let data = ArchiveContentLoader.extractEntryData(from: archiveURL, path: relativePath),
                  !data.isEmpty else {
                DispatchQueue.main.async {
                    guard self.archiveLoadToken == token, self.currentItem?.id == itemID else { return }
                    self.showArchivePreviewFailure(for: item)
                }
                return
            }

            if Self.isImageFile(named: item.name) {
                let image = Self.decodeImage(from: data, maxPixelSize: 4096)
                DispatchQueue.main.async {
                    guard self.archiveLoadToken == token, self.currentItem?.id == itemID else { return }
                    if let image {
                        self.archiveEntryData = data
                        self.showImagePreview(image)
                    } else {
                        self.showArchivePreviewFailure(for: item)
                    }
                }
                return
            }

            DispatchQueue.main.async {
                guard self.archiveLoadToken == token, self.currentItem?.id == itemID else { return }
                self.presentArchiveEntryData(data, for: item)
            }
        }
    }

    private func presentArchiveEntryData(_ data: Data, for item: FileItem) {
        archiveEntryData = data

        if InlineFilePreviewLoader.isTextPreviewable(fileName: item.name),
           let text = InlineFilePreviewLoader.decodeText(from: data) {
            showRichOrPlainText(text, for: item)
            return
        }

        if let tempURL = ArchiveContentLoader.writeEntryDataToTempFile(data, filename: item.name) {
            extractedTempURL = tempURL
            if showQuickLookPreview(for: tempURL) {
                return
            }
            cleanupExtractedTempFile()
        }

        showArchivePreviewFailure(for: item)
    }

    private func updateOpenButton(for item: FileItem?) {
        let canOpen = item.map { $0.isArchiveEntry && !$0.isContainer } ?? false
        openButton.isHidden = !canOpen
    }

    @objc private func openCurrentItemExternally() {
        guard let item = currentItem else { return }
        FileItemLauncher.open(item)
    }

    private func showArchivePreviewFailure(for item: FileItem) {
        placeholderView.configure(
            icon: FileIconCache.shared.icon(for: item),
            title: item.name,
            message: "This file could not be previewed from the archive. Use Open or double-click the file in the list."
        )
        showPlaceholderMode()
    }

    private static func isImageFile(named name: String) -> Bool {
        let ext = URL(fileURLWithPath: name).pathExtension
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image) && type.identifier != "public.svg-image"
    }

    private static func decodeImage(from data: Data, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(data: data)
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    private func cleanupExtractedTempFile() {
        guard let extractedTempURL else { return }
        try? FileManager.default.removeItem(at: extractedTempURL)
        self.extractedTempURL = nil
    }

    private func showRichOrPlainText(_ text: String, for item: FileItem) {
        currentSourceText = text
        currentRichFormat = RichTextPreviewFormat.format(forFileName: item.name)

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
        let baseURL = previewBaseURL(for: item)

        switch format {
        case .markdown:
            if let attributed = RichTextPreviewRenderer.renderedMarkdown(source, baseURL: baseURL) {
                showRenderedAttributedText(attributed)
            } else {
                showSourceText(source)
            }

        case .html:
            showHTMLPreview(for: item, source: source, baseURL: baseURL)

        case .svg:
            showSVGPreview(for: previewContentURL(for: item), source: source)
        }
    }

    private func previewContentURL(for item: FileItem) -> URL {
        if item.isArchiveEntry {
            return URL(fileURLWithPath: item.name)
        }
        return item.url
    }

    private func previewBaseURL(for item: FileItem) -> URL {
        if item.isArchiveEntry,
           let data = archiveEntryData,
           let tempURL = ArchiveContentLoader.writeEntryDataToTempFile(data, filename: item.name) {
            extractedTempURL = tempURL
            return tempURL.deletingLastPathComponent()
        }
        return item.url.deletingLastPathComponent()
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

    func refreshAppearance() {
        PreviewTheme.refreshSurfaceBackground(on: self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        PreviewTheme.applySurfaceBackground(to: self)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.textColor = .labelColor
        titleLabel.backgroundColor = .clear

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.lineBreakMode = .byTruncatingTail

        modeControl.segmentCount = 2
        modeControl.segmentStyle = .automatic
        modeControl.trackingMode = .selectOne
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        modeControl.isHidden = true

        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.font = .systemFont(ofSize: 11)
        openButton.target = self
        openButton.action = #selector(openCurrentItemExternally)
        openButton.isHidden = true

        topSeparator.boxType = .separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.wantsLayer = true
        contentContainer.layer?.masksToBounds = true

        configureSourceTextScroll(sourceScrollView, textView: sourceTextView)
        configureRenderedTextScroll(renderedScrollView, textView: renderedTextView)

        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        imageScrollView.hasVerticalScroller = true
        imageScrollView.hasHorizontalScroller = true
        imageScrollView.autohidesScrollers = true
        imageScrollView.borderType = .noBorder
        imageScrollView.drawsBackground = false
        imagePreviewView.imageScaling = .scaleProportionallyDown
        imagePreviewView.imageAlignment = .alignCenter
        imageScrollView.documentView = imagePreviewView

        svgImageView.translatesAutoresizingMaskIntoConstraints = false
        svgImageView.imageScaling = .scaleProportionallyDown
        svgImageView.imageAlignment = .alignCenter
        svgImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        svgImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        svgImageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        svgImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        placeholderView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(openButton)
        addSubview(modeControl)
        addSubview(subtitleLabel)
        addSubview(topSeparator)
        addSubview(contentContainer)
        contentContainer.addSubview(sourceScrollView)
        contentContainer.addSubview(renderedScrollView)
        contentContainer.addSubview(imageScrollView)
        contentContainer.addSubview(svgImageView)
        contentContainer.addSubview(placeholderView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: openButton.leadingAnchor, constant: -8),

            openButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            openButton.trailingAnchor.constraint(equalTo: modeControl.leadingAnchor, constant: -6),

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

            imageScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            imageScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            imageScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            imageScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

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

    private func showImagePreview(_ image: NSImage) {
        hideAllContentViews()
        imageScrollView.isHidden = false

        layoutSubtreeIfNeeded()
        let bounds = contentContainer.bounds.size
        let available = NSSize(width: max(1, bounds.width - 24), height: max(1, bounds.height - 24))
        let scaled = scaledImage(image, toFit: available)
        imagePreviewView.frame = NSRect(origin: .zero, size: scaled.size)
        imagePreviewView.image = scaled
        imageScrollView.documentView = imagePreviewView
        imageScrollView.reflectScrolledClipView(imageScrollView.contentView)
    }

    private func scaledImage(_ image: NSImage, toFit containerSize: NSSize) -> NSImage {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return image
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height, 1)
        let targetSize = NSSize(
            width: max(1, floor(imageSize.width * scale)),
            height: max(1, floor(imageSize.height * scale))
        )

        let scaled = NSImage(size: targetSize)
        scaled.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1
        )
        scaled.unlockFocus()
        return scaled
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
        imageScrollView.isHidden = true
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
        titleLabel.textColor = .labelColor
        titleLabel.backgroundColor = .clear
        titleLabel.alignment = .center
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingMiddle

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 11)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.backgroundColor = .clear
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
