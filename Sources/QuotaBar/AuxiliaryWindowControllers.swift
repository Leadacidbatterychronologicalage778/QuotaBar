import AppKit
import SwiftUI

@MainActor
final class SponsorWindowController {
    private let window: NSWindow

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "赞助 QuotaBar"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 440, height: 640)
        window.contentMaxSize = NSSize(width: 440, height: 640)
        window.contentView = NSHostingView(rootView: SponsorView())
        window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(openSponsor: @escaping () -> Void) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 690),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("QuotaBarSettingsWindow")
        window.title = "QuotaBar 设置"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 480, height: 690)
        window.contentMaxSize = NSSize(width: 480, height: 690)
        window.contentView = NSHostingView(
            rootView: SettingsView(openSponsor: openSponsor)
        )
        window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
