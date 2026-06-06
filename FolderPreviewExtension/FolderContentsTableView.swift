import AppKit

private final class NestedTableRowView: NSTableRowView {
    var nestingDepth: Int = 0

    override func drawBackground(in dirtyRect: NSRect) {
        if nestingDepth > 0 {
            let insetRect = bounds.insetBy(dx: 8, dy: 0)
            PreviewTheme.nestedRowBackground(for: nestingDepth).setFill()
            insetRect.fill()
        }
        super.drawBackground(in: dirtyRect)
    }
}

final class FolderContentsTableView: NSTableView {
    private let treeModel = FolderTreeModel()

    var textSize: PreviewTextSize = .small {
        didSet { applyStyle() }
    }

    var showThumbnails: Bool = true {
        didSet { reloadColumnLayout() }
    }

    var onSortColumn: ((PreviewColumn) -> Void)?
    var onRowCountChanged: ((Int) -> Void)?
    var onItemSelected: ((FileItem?) -> Void)?

    private let header = PreviewTableHeaderView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setRootItems(_ items: [FileItem]) {
        treeModel.setRootItems(items)
        reloadData()
        onRowCountChanged?(treeModel.displayRows.count)
    }

    func applySort() {
        treeModel.applySort()
        reloadData()
    }

    func visibleItemsForSummary() -> [FileItem] {
        treeModel.allVisibleItems
    }

    func reloadColumnLayout() {
        tableColumns.forEach { removeTableColumn($0) }

        for columnID in PreviewSettings.visibleColumnIDs {
            guard let column = PreviewColumn(rawValue: columnID) else { continue }
            if column == .preview, !showThumbnails { continue }

            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = column.title
            tableColumn.width = column.defaultWidth
            tableColumn.minWidth = column == .preview ? 44 : 56
            if column == .size {
                tableColumn.headerCell.alignment = .right
            }
            addTableColumn(tableColumn)
        }

        updateSortIndicators()
        reloadData()
    }

    func updateSortIndicators() {
        guard let active = PreviewColumn(rawValue: PreviewSettings.sortColumnID) else { return }
        let ascending = PreviewSettings.sortAscending

        for tableColumn in tableColumns {
            guard let column = PreviewColumn(rawValue: tableColumn.identifier.rawValue) else { continue }
            if column == active {
                tableColumn.headerCell.title = "\(column.title) \(ascending ? "↑" : "↓")"
            } else {
                tableColumn.headerCell.title = column.title
            }
        }
    }

    func makeColumnMenu() -> NSMenu {
        let menu = NSMenu(title: "Fields")
        menu.addItem(withTitle: "Choose fields", action: nil, keyEquivalent: "")

        for column in PreviewColumn.toggleable {
            let item = NSMenuItem(
                title: column.title,
                action: #selector(toggleColumn(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = column
            item.state = PreviewSettings.isColumnVisible(column) ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    @objc private func toggleColumn(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? PreviewColumn else { return }
        PreviewSettings.setColumnVisible(column, visible: sender.state != .on)
        reloadColumnLayout()
    }

    private func configure() {
        headerView = header
        header.columnMenuProvider = { [weak self] in self?.makeColumnMenu() }

        style = .plain
        allowsMultipleSelection = false
        usesAlternatingRowBackgroundColors = true
        gridStyleMask = []
        intercellSpacing = NSSize(width: 8, height: 4)
        columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        allowsColumnReordering = false
        allowsColumnResizing = true
        rowSizeStyle = .custom
        selectionHighlightStyle = .regular
        dataSource = self
        delegate = self
        target = self
        doubleAction = #selector(handleDoubleClick(_:))
        reloadColumnLayout()
        applyStyle()
    }

    @objc private func handleDoubleClick(_ sender: Any?) {
        let row = selectedRow
        guard row >= 0 else { return }
        openItem(atRow: row)
    }

    private func applyStyle() {
        rowHeight = max(textSize.rowHeight, showThumbnails ? textSize.thumbnailSize + 8 : textSize.rowHeight)
    }

    private func toggleFolder(atRow row: Int) {
        guard treeModel.displayRows.indices.contains(row) else { return }
        guard treeModel.displayRows[row].item.isContainer else { return }

        guard treeModel.toggleFolder(itemID: treeModel.displayRows[row].item.id) != nil else { return }

        reloadData()
        onRowCountChanged?(treeModel.displayRows.count)
        if let scrollView = enclosingScrollView {
            NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: scrollView.contentView)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)

        if row >= 0, treeModel.displayRows.indices.contains(row) {
            let columnIndex = column(at: point)
            if event.clickCount == 1,
               columnIndex >= 0,
               let columnID = PreviewColumn(rawValue: tableColumns[columnIndex].identifier.rawValue),
               columnID == .name,
               treeModel.displayRows[row].item.isContainer,
               let cell = view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? FolderNameCellView,
               cell.containsDisclosure(atWindowPoint: event.locationInWindow) {
                toggleFolder(atRow: row)
                return
            }

            if event.clickCount == 2 {
                openItem(atRow: row)
                return
            }
        }

        super.mouseDown(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        let columnIndex = column(at: point)

        if row >= 0,
           columnIndex >= 0,
           PreviewColumn(rawValue: tableColumns[columnIndex].identifier.rawValue) == .name,
           let cell = view(atColumn: columnIndex, row: row, makeIfNecessary: false) as? FolderNameCellView,
           cell.containsDisclosure(atWindowPoint: event.locationInWindow) {
            NSCursor.pointingHand.set()
            return
        }

        super.cursorUpdate(with: event)
    }

    func openItem(atRow row: Int) {
        guard treeModel.displayRows.indices.contains(row) else { return }
        let item = treeModel.displayRows[row].item

        if item.isArchiveEntry, item.isContainer {
            toggleFolder(atRow: row)
            return
        }

        FileItemLauncher.open(item)
    }
}

extension FolderContentsTableView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        treeModel.displayRows.count
    }
}

extension FolderContentsTableView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NestedTableRowView()
        if treeModel.displayRows.indices.contains(row) {
            rowView.nestingDepth = treeModel.displayRows[row].depth
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard treeModel.displayRows.indices.contains(row),
              let identifier = tableColumn?.identifier.rawValue,
              let column = PreviewColumn(rawValue: identifier) else {
            return nil
        }

        let displayRow = treeModel.displayRows[row]
        let item = displayRow.item

        switch column {
        case .preview:
            return makePreviewCell(for: displayRow, in: tableView)
        case .name:
            return makeNameCell(for: displayRow, in: tableView)
        default:
            return makeTextCell(for: displayRow, column: column, in: tableView)
        }
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let column = PreviewColumn(rawValue: tableColumn.identifier.rawValue),
              column != .preview else { return }
        onSortColumn?(column)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = selectedRow
        guard row >= 0, treeModel.displayRows.indices.contains(row) else {
            onItemSelected?(nil)
            return
        }
        onItemSelected?(treeModel.displayRows[row].item)
    }

    private func makePreviewCell(for displayRow: DisplayRow, in tableView: NSTableView) -> NSView {
        let id = NSUserInterfaceItemIdentifier("PreviewCell")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? IndentedPreviewCell ?? {
            IndentedPreviewCell()
        }()

        cell.identifier = id
        cell.configure(
            item: displayRow.item,
            depth: displayRow.depth,
            textSize: textSize,
            showThumbnails: showThumbnails
        )
        return cell
    }

    private func makeNameCell(for displayRow: DisplayRow, in tableView: NSTableView) -> NSView {
        let id = NSUserInterfaceItemIdentifier("FolderNameCell")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? FolderNameCellView ?? {
            FolderNameCellView()
        }()

        cell.identifier = id
        cell.configure(
            item: displayRow.item,
            depth: displayRow.depth,
            isExpanded: displayRow.isExpanded,
            textSize: textSize
        )

        return cell
    }

    private func makeTextCell(for displayRow: DisplayRow, column: PreviewColumn, in tableView: NSTableView) -> NSView {
        let id = NSUserInterfaceItemIdentifier("TextCell-\(column.rawValue)")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? IndentedTextCell ?? {
            IndentedTextCell()
        }()

        cell.identifier = id
        cell.configure(
            text: displayRow.item.value(for: column),
            depth: displayRow.depth,
            textSize: textSize,
            alignment: column == .size ? .right : .left
        )
        return cell
    }
}

// MARK: - Indented cell helpers

private final class IndentedPreviewCell: NSTableCellView {
    private let thumbnailView = NSImageView()
    private var leadingConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var representedItemID: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(thumbnailView)
        imageView = thumbnailView

        leadingConstraint = thumbnailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        widthConstraint = thumbnailView.widthAnchor.constraint(equalToConstant: 36)
        heightConstraint = thumbnailView.heightAnchor.constraint(equalToConstant: 36)

        NSLayoutConstraint.activate([
            leadingConstraint!,
            thumbnailView.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthConstraint!,
            heightConstraint!
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: FileItem, depth: Int, textSize: PreviewTextSize, showThumbnails: Bool) {
        let size = textSize.thumbnailSize
        representedItemID = item.id
        leadingConstraint?.constant = PreviewTheme.treeIndent(for: depth) + 8
        widthConstraint?.constant = size
        heightConstraint?.constant = size

        guard showThumbnails else {
            thumbnailView.image = FileIconCache.shared.icon(for: item)
            return
        }

        if item.isContainer {
            thumbnailView.image = nil
            return
        }

        guard item.supportsThumbnail else {
            thumbnailView.image = nil
            return
        }

        if let cached = ThumbnailProvider.shared.cachedThumbnail(for: item, size: size) {
            thumbnailView.image = cached
            return
        }

        thumbnailView.image = nil
        ThumbnailProvider.shared.thumbnail(for: item, size: size) { [weak self] image in
            guard let self,
                  self.representedItemID == item.id,
                  let image,
                  self.thumbnailView.superview != nil else { return }
            self.thumbnailView.image = image
        }
    }
}

private final class IndentedTextCell: NSTableCellView {
    private let label = NSTextField(labelWithString: "")
    private var leadingConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        textField = label

        leadingConstraint = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)

        NSLayoutConstraint.activate([
            leadingConstraint!,
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String, depth: Int, textSize: PreviewTextSize, alignment: NSTextAlignment) {
        leadingConstraint?.constant = PreviewTheme.treeIndent(for: depth) + 4
        label.font = PreviewTheme.bodyFont(size: textSize)
        label.textColor = depth > 0 ? .tertiaryLabelColor : .secondaryLabelColor
        label.alignment = alignment
        label.stringValue = text
    }
}
