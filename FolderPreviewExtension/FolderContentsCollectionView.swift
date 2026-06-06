import AppKit

final class FolderContentsCollectionView: NSView, NSCollectionViewDataSource, NSCollectionViewDelegate {
    var items: [FileItem] = [] {
        didSet { collectionView.reloadData() }
    }

    var onItemSelected: ((FileItem) -> Void)?

    var textSize: PreviewTextSize = .small {
        didSet { updateLayout() }
    }

    private var zoomFactor: Double = 1.0

    private let scrollView = NSScrollView()
    private let collectionView = NSCollectionView()
    private var gridLayout = NSCollectionViewGridLayout()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        PreviewTheme.applyRoundedScrollStyle(scrollView)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .legacy

        collectionView.collectionViewLayout = gridLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(FolderIconItem.self, forItemWithIdentifier: FolderIconItem.identifier)

        scrollView.documentView = collectionView
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateLayout()
    }

    func applyZoom(_ zoom: Double) {
        zoomFactor = zoom
        updateLayout()
    }

    private func updateLayout() {
        let size = textSize.iconGridSize * zoomFactor
        gridLayout = NSCollectionViewGridLayout()
        gridLayout.maximumNumberOfColumns = 0
        gridLayout.minimumItemSize = NSSize(width: size, height: size + 36)
        gridLayout.maximumItemSize = NSSize(width: size + 16, height: size + 44)
        gridLayout.margins = NSEdgeInsets(
            top: 8,
            left: PreviewTheme.contentInset,
            bottom: 8,
            right: PreviewTheme.contentInset
        )
        collectionView.collectionViewLayout = gridLayout
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: FolderIconItem.identifier,
            for: indexPath
        ) as! FolderIconItem

        if items.indices.contains(indexPath.item) {
            item.configure(
                with: items[indexPath.item],
                textSize: textSize,
                iconSize: textSize.iconGridSize * 0.55 * zoomFactor
            )
        }

        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let index = indexPaths.first?.item, items.indices.contains(index) else { return }
        onItemSelected?(items[index])
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        // Keep preview visible until another item is selected.
    }
}

final class FolderIconItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FolderIconItem")

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = PreviewTheme.cornerRadius

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 2

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.maximumNumberOfLines = 1

        view.addSubview(iconView)
        view.addSubview(nameLabel)
        view.addSubview(detailLabel)

        iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 48)
        iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 48)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconWidthConstraint!,
            iconHeightConstraint!,

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -4)
        ])
    }

    func configure(with item: FileItem, textSize: PreviewTextSize, iconSize: CGFloat) {
        nameLabel.font = PreviewTheme.captionFont(size: textSize)
        nameLabel.stringValue = item.name

        let dimensions = item.formattedDimensions
        if dimensions != "--" {
            detailLabel.font = .systemFont(ofSize: textSize.pointSize - 2)
            detailLabel.textColor = .linkColor
            detailLabel.stringValue = dimensions
            detailLabel.isHidden = false
        } else {
            detailLabel.isHidden = true
        }

        iconWidthConstraint?.constant = iconSize
        iconHeightConstraint?.constant = iconSize
        iconView.image = FileIconCache.shared.icon(for: item.url.path)

        if item.supportsThumbnail {
            ThumbnailProvider.shared.thumbnail(for: item.url, size: iconSize) { [weak self] image in
                if let image {
                    self?.iconView.image = image
                }
            }
        }
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected
                ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).cgColor
                : NSColor.clear.cgColor
        }
    }
}
