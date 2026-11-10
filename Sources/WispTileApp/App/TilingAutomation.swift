import AppKit
import WispTileCore

/// Drives the always-on tiling switches on the Layouts screen:
/// - "Tile new windows automatically" / Auto-Tile: when a new window appears on the current desktop,
///   the open windows are re-tiled with the selected layout.
/// - "Re-tile after display changes": when a display connects or disconnects, re-tile once things settle.
/// Nothing runs while automation is paused or Accessibility access is missing.
@MainActor
final class TilingAutomation {
    static let shared = TilingAutomation()

    private weak var appState: AppState?
    private var timer: Timer?
    private var known: Set<CGWindowID> = []
    private var pendingTile: DispatchWorkItem?

    /// The layout picked on the Layouts screen.
    private var selectedTemplate: String {
        UserDefaults.standard.string(forKey: "WispTile.selectedLayoutTemplate") ?? "Main + Stack"
    }

    func start(appState: AppState) {
        self.appState = appState
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForNewWindows() }
        }
        DisplayManager.shared.startMonitoring { _, flags in
            guard flags.contains(.addFlag) || flags.contains(.removeFlag) else { return }
            Task { @MainActor in TilingAutomation.shared.displaysChanged() }
        }
    }

    private var canRun: Bool {
        guard let s = appState else { return false }
        return !s.isAutomationPaused && WindowManager.shared.isAccessibilityGranted()
    }

    private func checkForNewWindows() {
        guard let s = appState, s.settings.autoTileNewWindows, canRun else { known = []; return }
        let ids = WindowManager.shared.onScreenWindowIDs()
        defer { known = ids }
        // The first look only records what's open; tile when a window appears after that.
        guard !known.isEmpty, !ids.subtracting(known).isEmpty else { return }
        scheduleTile(after: 0.6)
    }

    private func displaysChanged() {
        guard let s = appState, s.settings.retileAfterDisplayChange, canRun else { return }
        scheduleTile(after: 1.5) // let macOS finish moving windows between screens first
    }

    private func scheduleTile(after delay: TimeInterval) {
        pendingTile?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let s = self.appState, self.canRun else { return }
            _ = s.tileOpenWindows(presetName: self.selectedTemplate, takeSnapshot: false)
            self.known = WindowManager.shared.onScreenWindowIDs()
        }
        pendingTile = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
