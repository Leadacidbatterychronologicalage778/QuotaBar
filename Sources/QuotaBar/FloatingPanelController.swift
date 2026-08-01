import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject {
    private static let frameAutosaveName = "QuotaBar.FloatingHUD"

    private let panel: NSPanel
    private let preferences: AppPreferences
    private var cancellables: Set<AnyCancellable> = []
    private var screenObserver: NSObjectProtocol?

    init(model: AppModel, preferences: AppPreferences) {
        self.preferences = preferences
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 176),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.title = "QuotaBar 悬浮窗"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(
            rootView: FloatingHUDView(model: model) { [weak preferences] in
                preferences?.showFloatingPanel = false
            }
        )

        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            positionAtTopRight()
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        ensureVisibleOnAvailableScreen()

        preferences.$floatingAcrossSpaces
            .removeDuplicates()
            .sink { [weak self] in self?.applySpaceBehavior(acrossSpaces: $0) }
            .store(in: &cancellables)

        preferences.$showFloatingPanel
            .removeDuplicates()
            .sink { [weak self] in self?.applyVisibility(isVisible: $0) }
            .store(in: &cancellables)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureVisibleOnAvailableScreen()
            }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func toggle() {
        preferences.showFloatingPanel.toggle()
    }

    private func applyVisibility(isVisible: Bool) {
        if isVisible {
            ensureVisibleOnAvailableScreen()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func applySpaceBehavior(acrossSpaces: Bool) {
        panel.collectionBehavior = acrossSpaces
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.managed]

        if panel.isVisible {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    private func ensureVisibleOnAvailableScreen() {
        let visibleSomewhere = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersection(panel.frame).width >= 80
                && screen.visibleFrame.intersection(panel.frame).height >= 60
        }
        if !visibleSomewhere {
            positionAtTopRight()
        }
    }

    private func positionAtTopRight() {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - 24,
            y: visibleFrame.maxY - panel.frame.height - 24
        )
        panel.setFrameOrigin(origin)
    }
}
