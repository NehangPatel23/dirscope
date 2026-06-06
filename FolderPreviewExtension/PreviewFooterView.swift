import AppKit

final class PreviewFooterView: NSView {
    static let preferredHeight: CGFloat = 64
    static let bottomInset: CGFloat = 8

    static var totalHeight: CGFloat { preferredHeight + bottomInset }

    var onViewModeChanged: ((PreviewViewMode) -> Void)?
    var onIconZoomChanged: ((Double) -> Void)?

    private let pathScrollView = NSScrollView()
    private let pathStack = NSStackView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let viewModeControl = NSSegmentedControl()
    private let zoomSlider = NSSlider()
    private let topSeparator = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(
        pathComponents: [PathComponent],
        statusText: String,
        viewMode: PreviewViewMode,
        showPathBar: Bool,
        iconZoom: Double
    ) {
        pathScrollView.isHidden = !showPathBar
        statusLabel.stringValue = statusText

        pathStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, component) in pathComponents.enumerated() {
            if index > 0 {
                pathStack.addArrangedSubview(makeSeparatorLabel())
            }
            pathStack.addArrangedSubview(makePathButton(component))
        }

        let modeIndex = PreviewViewMode.allCases.firstIndex(of: viewMode) ?? 0
        if viewModeControl.selectedSegment != modeIndex {
            viewModeControl.selectedSegment = modeIndex
        }

        zoomSlider.doubleValue = iconZoom
        zoomSlider.isHidden = viewMode != .icon
    }

    private func setup() {
        topSeparator.boxType = .separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false

        pathScrollView.translatesAutoresizingMaskIntoConstraints = false
        pathScrollView.hasVerticalScroller = false
        pathScrollView.hasHorizontalScroller = true
        pathScrollView.autohidesScrollers = true
        pathScrollView.drawsBackground = false
        pathScrollView.borderType = .noBorder
        pathScrollView.scrollerStyle = .overlay

        pathStack.orientation = .horizontal
        pathStack.alignment = .centerY
        pathStack.spacing = 2
        pathStack.translatesAutoresizingMaskIntoConstraints = false
        pathScrollView.documentView = pathStack

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center

        viewModeControl.segmentCount = 2
        viewModeControl.setImage(NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "List"), forSegment: 0)
        viewModeControl.setImage(NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Icons"), forSegment: 1)
        viewModeControl.segmentStyle = .automatic
        viewModeControl.trackingMode = .selectOne
        viewModeControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeControl.target = self
        viewModeControl.action = #selector(viewModeChanged)

        zoomSlider.minValue = 0.6
        zoomSlider.maxValue = 1.6
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.target = self
        zoomSlider.action = #selector(zoomChanged)

        addSubview(topSeparator)
        addSubview(pathScrollView)
        addSubview(statusLabel)
        addSubview(viewModeControl)
        addSubview(zoomSlider)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),

            pathScrollView.topAnchor.constraint(equalTo: topSeparator.bottomAnchor, constant: 8),
            pathScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            pathScrollView.trailingAnchor.constraint(equalTo: viewModeControl.leadingAnchor, constant: -8),
            pathScrollView.heightAnchor.constraint(equalToConstant: 22),

            pathStack.topAnchor.constraint(equalTo: pathScrollView.contentView.topAnchor),
            pathStack.leadingAnchor.constraint(equalTo: pathScrollView.contentView.leadingAnchor),
            pathStack.trailingAnchor.constraint(greaterThanOrEqualTo: pathScrollView.contentView.trailingAnchor),
            pathStack.heightAnchor.constraint(equalTo: pathScrollView.contentView.heightAnchor),

            statusLabel.topAnchor.constraint(equalTo: pathScrollView.bottomAnchor, constant: 6),
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            viewModeControl.centerYAnchor.constraint(equalTo: pathScrollView.centerYAnchor),
            viewModeControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            viewModeControl.widthAnchor.constraint(equalToConstant: 68),

            zoomSlider.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            zoomSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            zoomSlider.widthAnchor.constraint(equalToConstant: 90),

            heightAnchor.constraint(equalToConstant: Self.preferredHeight)
        ])
    }

    private func makeSeparatorLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "›")
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func makePathButton(_ component: PathComponent) -> NSButton {
        let button = NSButton(title: component.name, target: nil, action: nil)
        button.isBordered = false
        button.font = .systemFont(ofSize: 11)
        button.image = component.icon
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return button
    }

    @objc private func viewModeChanged() {
        let mode = PreviewViewMode.allCases[viewModeControl.selectedSegment]
        PreviewSettings.viewMode = mode
        zoomSlider.isHidden = mode != .icon
        onViewModeChanged?(mode)
    }

    @objc private func zoomChanged() {
        PreviewSettings.iconZoom = zoomSlider.doubleValue
        onIconZoomChanged?(zoomSlider.doubleValue)
    }
}

struct PathComponent {
    let name: String
    let url: URL?
    let icon: NSImage?

    static func build(for url: URL, isArchive: Bool) -> [PathComponent] {
        var components: [PathComponent] = []
        components.append(PathComponent(
            name: FileManager.default.displayName(atPath: "/"),
            url: URL(fileURLWithPath: "/"),
            icon: NSImage(named: NSImage.computerName)
        ))

        if isArchive {
            for part in url.deletingLastPathComponent().pathComponents where part != "/" {
                components.append(PathComponent(
                    name: part,
                    url: nil,
                    icon: NSImage(named: NSImage.folderName)
                ))
            }
            components.append(PathComponent(
                name: url.lastPathComponent,
                url: url,
                icon: NSImage(named: NSImage.multipleDocumentsName)
            ))
        } else {
            var current = url
            var chain: [PathComponent] = []
            while current.path != "/" {
                chain.insert(PathComponent(
                    name: current.lastPathComponent,
                    url: current,
                    icon: NSImage(named: NSImage.folderName)
                ), at: 0)
                current.deleteLastPathComponent()
            }
            components.append(contentsOf: chain)
        }

        return components
    }
}
