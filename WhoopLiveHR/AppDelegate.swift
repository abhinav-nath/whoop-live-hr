import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let heartRateMonitor = WhoopHeartRateMonitor()

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
            heartRateMonitor: heartRateMonitor
        )
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        heartRateMonitor.shutdown()
    }
}
