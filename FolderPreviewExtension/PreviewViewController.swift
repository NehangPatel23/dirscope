import AppKit
import QuickLookUI

final class PreviewViewController: NSViewController, QLPreviewingController, QLPreviewPanelDelegate {
    private let tableView = FolderContentsTableView()
    private let collectionView = FolderContentsCollectionView()
    private let previewPane = FilePreviewPaneView()
    private let paneSeparator = NSBox()
    private let footerView = PreviewFooterView()
    private let emptyStateView = EmptyStateView()
    private var tableScrollView: NSScrollView!
    private var currentURL: URL?
    private var securityScopedURL: URL?
    private var isArchive = false
    private var rootItems: [FileItem] = []
    private var settingsDarwinObserver: UnsafeMutableRawPointer?
    private var isApplyingSettingsChange = false
    private var archiveDoubleClickMonitor: Any?

    override var nibName: NSNib.Name? { nil }

    override var preferredContentSize: NSSize {
        get { PreviewLayout.contentSize }
        set { super.preferredContentSize = newValue }
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: PreviewLayout.contentSize))
        preferredContentSize = PreviewLayout.contentSize
        PreviewSettings.registerDefaults()
        setupUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sharedSettingsDidChange),
            name: .previewSettingsDidChange,
            object: nil
        )

        settingsDarwinObserver = SharedPreferencesStore.addDarwinObserver { [weak self] in
            self?.sharedSettingsDidChange()
        }
    }

    func preparePreviewOfFile(at url: URL) async throws {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }

        currentURL = url.resolvingSymlinksInPath()
        isArchive = ArchiveContentLoader.isArchive(url)

        let previewURL = currentURL!
        let sorted: [FileItem]
        if isArchive {
            sorted = FolderContentLoader.sorted(ArchiveContentLoader.loadContents(of: previewURL))
        } else {
            sorted = FolderContentLoader.sorted(FolderContentLoader.loadContents(of: previewURL))
        }

        await MainActor.run {
            PreviewSettings.reloadFromDisk()
            rootItems = sorted
            applySettings(reloadColumns: false)
            tableView.setRootItems(sorted)
            collectionView.items = sorted
            previewPane.show(item: nil)
            refreshFooter()
            updateVisibleContent(itemsEmpty: sorted.isEmpty)
            applyPreferredPanelSize()
            syncTableScrollerInsets()
            syncTableDocumentFrame()
            updateArchiveDoubleClickGuard()
            updateArchivePanelControl()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateArchivePanelControl()
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        isArchive
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        if panel.delegate as AnyObject? === self {
            panel.delegate = nil
        }
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard isArchive else { return false }

        if (event.type == .leftMouseDown || event.type == .leftMouseUp), event.clickCount >= 2 {
            handleArchiveDoubleClick(at: event.locationInWindow)
            return true
        }

        if event.type == .keyDown, event.keyCode == 36 || event.keyCode == 76 {
            openSelectedArchiveEntry()
            return true
        }

        return false
    }

    private func applyPreferredPanelSize() {
        preferredContentSize = PreviewLayout.contentSize
        view.setFrameSize(PreviewLayout.contentSize)
        if let window = view.window {
            window.setContentSize(PreviewLayout.contentSize)
        }
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = PreviewTheme.backgroundColor.cgColor

        tableScrollView = NSScrollView()
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        PreviewTheme.applyRoundedScrollStyle(tableScrollView)
        tableScrollView.hasVerticalScroller = true
        tableScrollView.hasHorizontalScroller = false
        tableScrollView.autohidesScrollers = true
        tableScrollView.scrollerStyle = .legacy
        tableScrollView.documentView = tableView
        tableView.frame = NSRect(
            x: 0,
            y: 0,
            width: PreviewLayout.listPaneWidth,
            height: PreviewLayout.defaultHeight - PreviewFooterView.totalHeight
        )

        collectionView.translatesAutoresizingMaskIntoConstraints = false

        paneSeparator.boxType = .separator
        paneSeparator.translatesAutoresizingMaskIntoConstraints = false

        previewPane.translatesAutoresizingMaskIntoConstraints = false
        footerView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        footerView.onViewModeChanged = { [weak self] mode in
            self?.switchViewMode(mode)
        }
        footerView.onIconZoomChanged = { [weak self] _ in
            self?.collectionView.applyZoom(PreviewSettings.iconZoom)
        }

        tableView.onSortColumn = { [weak self] column in
            self?.handleSort(column)
        }
        tableView.onRowCountChanged = { [weak self] _ in
            self?.refreshFooter()
            self?.syncTableScrollerInsets()
            self?.syncTableDocumentFrame()
        }
        tableView.onItemSelected = { [weak self] item in
            self?.previewPane.show(item: item)
        }

        collectionView.onItemSelected = { [weak self] item in
            self?.previewPane.show(item: item)
        }

        view.addSubview(tableScrollView)
        view.addSubview(collectionView)
        view.addSubview(paneSeparator)
        view.addSubview(previewPane)
        view.addSubview(footerView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            tableScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableScrollView.trailingAnchor.constraint(equalTo: paneSeparator.leadingAnchor),
            tableScrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: paneSeparator.leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

            paneSeparator.topAnchor.constraint(equalTo: view.topAnchor),
            paneSeparator.bottomAnchor.constraint(equalTo: footerView.topAnchor),
            paneSeparator.widthAnchor.constraint(equalToConstant: 1),

            previewPane.topAnchor.constraint(equalTo: view.topAnchor),
            previewPane.leadingAnchor.constraint(equalTo: paneSeparator.trailingAnchor),
            previewPane.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewPane.bottomAnchor.constraint(equalTo: footerView.topAnchor),
            previewPane.widthAnchor.constraint(equalToConstant: PreviewLayout.previewPaneWidth),

            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -PreviewFooterView.bottomInset),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10)
        ])

        applySettings(reloadColumns: true)
        switchViewMode(PreviewSettings.viewMode)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidResize),
            name: NSView.frameDidChangeNotification,
            object: tableScrollView.contentView
        )

    }

    override func viewDidLayout() {
        super.viewDidLayout()
        syncTableScrollerInsets()
        syncTableDocumentFrame()
    }

    @objc private func scrollViewDidResize() {
        syncTableScrollerInsets()
        syncTableDocumentFrame()
    }

    @objc private func sharedSettingsDidChange() {
        guard !isApplyingSettingsChange else { return }
        isApplyingSettingsChange = true
        defer { isApplyingSettingsChange = false }

        PreviewSettings.reloadFromDisk()
        guard currentURL != nil else { return }
        reloadFromCurrentSettings()
    }

    private func reloadFromCurrentSettings() {
        guard let currentURL else { return }

        let sorted: [FileItem]
        if isArchive {
            sorted = FolderContentLoader.sorted(ArchiveContentLoader.loadContents(of: currentURL))
        } else {
            sorted = FolderContentLoader.sorted(FolderContentLoader.loadContents(of: currentURL))
        }

        rootItems = sorted
        applySettings(reloadColumns: true)
        tableView.setRootItems(sorted)
        collectionView.items = sorted
        tableView.applySort()
        tableView.updateSortIndicators()
        switchViewMode(PreviewSettings.viewMode)
        refreshFooter()
        updateVisibleContent(itemsEmpty: sorted.isEmpty)
        syncTableScrollerInsets()
        syncTableDocumentFrame()
    }

    private func syncTableScrollerInsets() {
        guard tableScrollView != nil, !tableScrollView.isHidden else { return }
        tableView.layoutSubtreeIfNeeded()
        let headerHeight = tableView.headerView?.frame.height ?? 0
        tableScrollView.scrollerInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
    }

    private static let tableBottomScrollPadding: CGFloat = 16

    private func syncTableDocumentFrame() {
        guard tableScrollView != nil, !tableScrollView.isHidden else { return }
        let clipSize = tableScrollView.contentView.bounds.size
        guard clipSize.width > 1, clipSize.height > 1 else { return }

        tableView.layoutSubtreeIfNeeded()
        tableView.frame.size.width = clipSize.width

        let rows = tableView.numberOfRows
        let bottomPadding = tableView.rowHeight * 0.5 + Self.tableBottomScrollPadding
        let contentHeight: CGFloat
        if rows > 0 {
            let lastRowMaxY = tableView.rect(ofRow: rows - 1).maxY
            contentHeight = lastRowMaxY + bottomPadding
        } else {
            contentHeight = (tableView.headerView?.frame.height ?? 24) + bottomPadding
        }

        tableView.frame.size.height = max(contentHeight, clipSize.height)
        tableView.needsDisplay = true
    }

    private func applySettings(reloadColumns: Bool = false) {
        let textSize = PreviewSettings.textSize
        tableView.textSize = textSize
        tableView.showThumbnails = PreviewSettings.showThumbnails
        if reloadColumns {
            tableView.reloadColumnLayout()
            syncTableDocumentFrame()
        }
        collectionView.textSize = textSize
        collectionView.applyZoom(PreviewSettings.iconZoom)
    }

    private func refreshFooter() {
        guard let currentURL else { return }
        let visible = tableView.visibleItemsForSummary()
        let summaryItems = visible.isEmpty ? rootItems : visible
        let count = summaryItems.count
        let sizeText = FileItemSummary.formattedTotalSize(of: summaryItems)
        let status = count == 0
            ? "Nothing here"
            : "\(count) item\(count == 1 ? "" : "s") · \(sizeText)"

        footerView.configure(
            pathComponents: PathComponent.build(for: currentURL, isArchive: isArchive),
            statusText: status,
            viewMode: PreviewSettings.viewMode,
            showPathBar: PreviewSettings.showPathBar,
            iconZoom: PreviewSettings.iconZoom
        )
    }

    private func switchViewMode(_ mode: PreviewViewMode) {
        let isList = mode == .list
        tableScrollView.isHidden = !isList
        collectionView.isHidden = isList
        refreshFooter()
    }

    private func updateVisibleContent(itemsEmpty: Bool) {
        let showContent = !itemsEmpty
        let isList = PreviewSettings.viewMode == .list
        tableScrollView.isHidden = !showContent || !isList
        collectionView.isHidden = !showContent || isList
        paneSeparator.isHidden = !showContent
        previewPane.isHidden = !showContent
        footerView.isHidden = !showContent
        emptyStateView.isHidden = showContent
    }

    private func handleSort(_ column: PreviewColumn) {
        if PreviewSettings.sortColumnID == column.rawValue {
            PreviewSettings.sortAscending.toggle()
        } else {
            PreviewSettings.sortColumnID = column.rawValue
            PreviewSettings.sortAscending = [.size, .dateModified, .dateCreated, .dateLastOpened, .dateAdded].contains(column)
                ? false
                : true
        }

        tableView.applySort()
        collectionView.items = FolderContentLoader.sorted(rootItems)
        tableView.updateSortIndicators()
        refreshFooter()
    }

    private func updateArchivePanelControl() {
        guard isArchive, view.window != nil else { return }
        QLPreviewPanel.shared()?.updateController()
    }

    private func updateArchiveDoubleClickGuard() {
        removeArchiveDoubleClickGuard()
        guard isArchive else { return }

        archiveDoubleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self, self.isArchive, event.clickCount >= 2 else { return event }

            let pointInView = self.view.convert(event.locationInWindow, from: nil)
            guard self.view.bounds.contains(pointInView) else { return event }

            self.handleArchiveDoubleClick(at: event.locationInWindow)
            return nil
        }
    }

    private func removeArchiveDoubleClickGuard() {
        if let archiveDoubleClickMonitor {
            NSEvent.removeMonitor(archiveDoubleClickMonitor)
            self.archiveDoubleClickMonitor = nil
        }
    }

    private func handleArchiveDoubleClick(at windowPoint: NSPoint) {
        if !tableScrollView.isHidden {
            let pointInScroll = tableScrollView.convert(windowPoint, from: nil)
            if tableScrollView.bounds.contains(pointInScroll) {
                let pointInTable = tableView.convert(windowPoint, from: nil)
                let row = tableView.row(at: pointInTable)
                if row >= 0 {
                    tableView.openItem(atRow: row)
                    return
                }
            }
        }

        if !collectionView.isHidden {
            let pointInCollection = collectionView.convert(windowPoint, from: nil)
            if collectionView.bounds.contains(pointInCollection) {
                collectionView.openItem(at: windowPoint)
                return
            }
        }

        openSelectedArchiveEntry()
    }

    private func openSelectedArchiveEntry() {
        if !tableScrollView.isHidden {
            let row = tableView.selectedRow
            guard row >= 0 else { return }
            tableView.openItem(atRow: row)
            return
        }

        if !collectionView.isHidden {
            collectionView.openSelectedItem()
        }
    }

    deinit {
        removeArchiveDoubleClickGuard()
        if let settingsDarwinObserver {
            SharedPreferencesStore.removeDarwinObserver(settingsDarwinObserver)
        }
        NotificationCenter.default.removeObserver(self)
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }
}

private final class EmptyStateView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "No items here")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        iconView.contentTintColor = .tertiaryLabelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor

        addSubview(iconView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
