import Foundation
import Carbon
import AppKit

public struct HotKey: Sendable {
    public let id: UInt32
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let name: String
    
    public init(id: UInt32, keyCode: UInt32, modifiers: UInt32, name: String) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.name = name
    }
}

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()
    
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?
    
    // FourCC signature for WispTile hotkeys: 'WISP'
    private let signature: OSType = 0x57495350
    
    public init() {
        installCarbonHandler()
    }
    
    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData, let theEvent = theEvent else {
                    return noErr
                }
                
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr && hotKeyID.signature == manager.signature {
                    Task { @MainActor in
                        manager.dispatchHotKey(id: hotKeyID.id)
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }
    
    private func dispatchHotKey(id: UInt32) {
        handlers[id]?()
    }
    
    /// Registers a global hotkey with Carbon
    @discardableResult
    public func register(hotKey: HotKey, handler: @escaping () -> Void) -> Bool {
        unregister(id: hotKey.id)
        
        let hotKeyID = EventHotKeyID(signature: signature, id: hotKey.id)
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        guard status == noErr, let ref = hotKeyRef else {
            print("Failed to register hotkey '\(hotKey.name)': OSStatus \(status)")
            return false
        }
        
        hotKeyRefs[hotKey.id] = ref
        handlers[hotKey.id] = handler
        return true
    }
    
    /// Unregisters a global hotkey
    public func unregister(id: UInt32) {
        if let ref = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers.removeValue(forKey: id)
    }
    
    deinit {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
