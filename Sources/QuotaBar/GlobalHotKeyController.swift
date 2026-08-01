import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
final class GlobalHotKeyController: ObservableObject {
    static let shared = GlobalHotKeyController()

    @Published private(set) var errorMessage: String?
    var onToggle: (() -> Void)?

    private let preferences = AppPreferences.shared
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var cancellable: AnyCancellable?

    private static let signature: OSType = 0x5142_4152 // QBAR
    private static let hotKeyID = UInt32(1)

    private init() {
        installEventHandler()
        cancellable = preferences.$globalHotKeyEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.updateRegistration(enabled: enabled)
            }
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr,
                      hotKeyID.signature == GlobalHotKeyController.signature,
                      hotKeyID.id == GlobalHotKeyController.hotKeyID
                else {
                    return status
                }

                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.onToggle?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func updateRegistration(enabled: Bool) {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }

        guard enabled else {
            errorMessage = nil
            return
        }

        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.hotKeyID
        )
        let modifiers = UInt32(cmdKey) | UInt32(optionKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        if status == noErr {
            errorMessage = nil
        } else {
            hotKey = nil
            errorMessage = "⌥⌘Q 已被其他应用占用，请关闭全局快捷键。"
        }
    }
}
