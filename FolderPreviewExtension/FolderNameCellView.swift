import AppKit

final class FolderNameCellView: NSTableCellView {
    private let disclosureView = NSImageView()
    private let fileIconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private var indentConstraint: NSLayoutConstraint?
    private var isFolderRow = false

    private var disclosureHitRect: NSRect {
        disclosureView.frame.insetBy(dx: -4, dy: -4)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(
        item: FileItem,
        depth: Int,
        isExpanded: Bool,
        textSize: PreviewTextSize
    ) {
        isFolderRow = item.isContainer
        indentConstraint?.constant = PreviewTheme.treeIndent(for: depth) + 4

        if item.isContainer {
            disclosureView.alphaValue = 1
            let symbol = isExpanded ? "chevron.down" : "chevron.right"
            disclosureView.image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: isExpanded ? "Open" : "Closed"
            )
            disclosureView.contentTintColor = .secondaryLabelColor

            let attrs: [NSAttributedString.Key: Any] = [
                .font: PreviewTheme.bodyFont(size: textSize),
                .foregroundColor: NSColor.labelColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            nameField.attributedStringValue = NSAttributedString(string: item.name, attributes: attrs)
        } else {
            disclosureView.alphaValue = 0
            disclosureView.image = nil
            nameField.font = PreviewTheme.bodyFont(size: textSize)
            nameField.textColor = depth > 0 ? .secondaryLabelColor : .labelColor
            nameField.stringValue = item.name
        }

        fileIconView.image = FileIconCache.shared.icon(for: item)
        window?.invalidateCursorRects(for: self)
    }

    func containsDisclosure(atWindowPoint windowPoint: NSPoint) -> Bool {
        guard isFolderRow, disclosureView.alphaValue > 0 else { return false }
        let localPoint = convert(windowPoint, from: nil)
        return disclosureHitRect.contains(localPoint)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isFolderRow, disclosureView.alphaValue > 0 else { return }
        addCursorRect(disclosureHitRect, cursor: .pointingHand)
    }

    override func cursorUpdate(with event: NSEvent) {
        if containsDisclosure(atWindowPoint: event.locationInWindow) {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    private func setup() {
        disclosureView.translatesAutoresizingMaskIntoConstraints = false
        disclosureView.imageScaling = .scaleProportionallyDown

        fileIconView.translatesAutoresizingMaskIntoConstraints = false
        fileIconView.imageScaling = .scaleProportionallyUpOrDown

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.lineBreakMode = .byTruncatingMiddle
        nameField.isSelectable = false

        addSubview(disclosureView)
        addSubview(fileIconView)
        addSubview(nameField)

        imageView = fileIconView
        textField = nameField

        indentConstraint = disclosureView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)

        NSLayoutConstraint.activate([
            indentConstraint!,
            disclosureView.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosureView.widthAnchor.constraint(equalToConstant: 14),
            disclosureView.heightAnchor.constraint(equalToConstant: 14),

            fileIconView.leadingAnchor.constraint(equalTo: disclosureView.trailingAnchor, constant: 4),
            fileIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            fileIconView.widthAnchor.constraint(equalToConstant: 16),
            fileIconView.heightAnchor.constraint(equalToConstant: 16),

            nameField.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
