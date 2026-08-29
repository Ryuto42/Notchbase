import AppKit

final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var controller: NotchController?

    init(controller: NotchController) {
        self.controller = controller
        super.init()

        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                     accessibilityDescription: "Notchbase")

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Notchbase", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Reposition", action: #selector(reposition), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Notchbase", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }

    @objc private func toggle() { controller?.toggleExpanded() }
    @objc private func openSettings() { controller?.openSettings() }
    @objc private func reposition() { controller?.rebuild() }
    @objc private func checkForUpdates() { UpdateController.shared.checkNow() }
}
