import AppKit

final class PreviewTableHeaderView: NSTableHeaderView {
    var columnMenuProvider: (() -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        columnMenuProvider?() ?? super.menu(for: event)
    }
}
