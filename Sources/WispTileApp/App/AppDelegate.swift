import AppKit
import SwiftUI
import Carbon
import WispTileCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState = AppState.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // The designs are light-only; default-coloured text would turn white on white cards in Dark mode.
        NSApp.appearance = NSAppearance(named: .aqua)
        RenderHarness.runIfRequested()
        setupMenuBarStatusItem()
        setupGlobalHotkeys()
        TilingAutomation.shared.start(appState: appState)
    }
    
    private func setupMenuBarStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let url = Bundle.main.url(forResource: "WispTileMenuBarIcon", withExtension: "png"), let icon = NSImage(contentsOf: url) {
                icon.size = NSSize(width: 22, height: 16)
                icon.isTemplate = false
                button.image = icon
                button.imageScaling = .scaleProportionallyDown
            } else if let url = Bundle.main.url(forResource: "WispTileLogo", withExtension: "png"), let logo = NSImage(contentsOf: url) {
                logo.size = NSSize(width: 18, height: 18)
                button.image = logo
            } else {
                button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "WispTile")
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        let popover = NSPopover()
        popover.behavior = .transient
        let host = NSHostingController(rootView: MenuBarPopoverView(appState: appState))
        host.sizingOptions = [.preferredContentSize] // the popover fits its content (Board 18)
        popover.contentViewController = host
        self.popover = popover
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            appState.refreshAll()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    /// Registers a global shortcut and remembers it in `hotkeyConflicts` when macOS refuses it
    /// (usually because another app already owns the same key combination).
    private func registerHotKey(_ key: HotKey, keys: String, handler: @escaping () -> Void) {
        if !HotKeyManager.shared.register(hotKey: key, handler: handler) {
            appState.hotkeyConflicts.insert(keys)
        }
    }
    
    private func setupGlobalHotkeys() {
        // Ctrl+⌥ avoids blocking characters produced by bare Option shortcuts.
        let quickSwitcherKey = HotKey(id: 100, keyCode: 49, modifiers: UInt32(controlKey | optionKey), name: "Control+Option+Space Quick Switcher")
        registerHotKey(quickSwitcherKey, keys: "⌃⌥Space") { [weak self] in
            Task { @MainActor in
                self?.appState.showingQuickSwitcher.toggle()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        let captureKey = HotKey(id: 101, keyCode: 8, modifiers: UInt32(controlKey | optionKey), name: "Control+Option+C Capture")
        registerHotKey(captureKey, keys: "⌃⌥C") { [weak self] in
            Task { @MainActor in
                self?.appState.showingCaptureSheet = true
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        // Ctrl+⌥1…Ctrl+⌥9 Restore the Nth project
        let digitKeyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        for (i, code) in digitKeyCodes.enumerated() {
            let key = HotKey(id: UInt32(102 + i), keyCode: code, modifiers: UInt32(controlKey | optionKey), name: "Control+Option+\(i + 1) Restore Project \(i + 1)")
            registerHotKey(key, keys: "⌃⌥\(i + 1)") { [weak self] in
                Task { @MainActor in
                    guard let self = self, i < self.appState.projects.count else { return }
                    await self.appState.executeRestore(for: self.appState.projects[i])
                }
            }
        }
    }
}
