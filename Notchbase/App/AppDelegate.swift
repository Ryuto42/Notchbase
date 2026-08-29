import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notch: NotchController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchController()
        controller.start()
        notch = controller
        statusItem = StatusItemController(controller: controller)
        UpdateController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notch?.stop()
    }
}
