import AppKit
import Carbon.HIToolbox
import ClipboardManagerCore

enum HotkeyRegistrationResult {
    case success
    case conflict
    case failure(OSStatus)
}

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void

    private(set) var current: HotkeyConfig?

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    /// Registers the config, replacing any current registration.
    @discardableResult
    func register(_ config: HotkeyConfig) -> HotkeyRegistrationResult {
        guard config.isValid else { return .failure(OSStatus(paramErr)) }
        installHandlerIfNeeded()
        unregisterHotKeyOnly()

        let signature: OSType = 0x434C5042 // 'CLPB'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(config.keyCode,
                                         config.modifiers.rawValue,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        if status == noErr {
            current = config
            return .success
        }

        hotKeyRef = nil
        if status == OSStatus(eventHotKeyExistsErr) {
            return .conflict
        }
        return .failure(status)
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(),
                                         { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger()
            return noErr
        },
                                         1,
                                         [eventSpec],
                                         Unmanaged.passUnretained(self).toOpaque(),
                                         &eventHandler)
        if status != noErr {
            NSLog("Pastewell: InstallEventHandler failed (\(status))")
        }
    }

    private func unregisterHotKeyOnly() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    func unregister() {
        unregisterHotKeyOnly()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit { unregister() }
}