import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let heartRateManager = HeartRateManager()

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        /*
         Make this a menu-bar utility rather than
         a normal Dock application.
         */
        NSApplication.shared.setActivationPolicy(.accessory)

        statusBarController = StatusBarController(
            heartRateManager: heartRateManager
        )
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        heartRateManager.shutdown()
    }
}
