import AppKit
import SwiftUI

@MainActor
final class QuotaBarAppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        showMainWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    private func showMainWindow() {
        let window: NSWindow

        if let mainWindow {
            window = mainWindow
        } else {
            let model = AppModel.shared
            let rootView = MenuContentView(model: model)
                .task {
                    await model.start()
                }
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 620),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "QuotaBar"
            newWindow.contentView = NSHostingView(rootView: rootView)
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            mainWindow = newWindow
            window = newWindow
        }

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct QuotaBarApp: App {
    @NSApplicationDelegateAdaptor(QuotaBarAppDelegate.self)
    private var appDelegate

    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
                .task {
                    await model.start()
                }
        } label: {
            MenuBarStatusLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }

        Window("赞助 QuotaBar", id: "sponsor") {
            SponsorView()
        }
        .defaultSize(width: 440, height: 640)
        .windowResizability(.contentSize)
    }
}
