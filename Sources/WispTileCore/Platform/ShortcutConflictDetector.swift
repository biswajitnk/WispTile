import Foundation

public struct ShortcutConflict: Sendable, Equatable {
    public let shortcut: String
    public let conflictingAppOrFeature: String
    public let severity: ConflictSeverity
    public let recommendation: String
}

public enum ConflictSeverity: String, Sendable {
    case warning = "warning"
    case error = "error"
}

public final class ShortcutConflictDetector: Sendable {
    public static let shared = ShortcutConflictDetector()
    
    public init() {}
    
    // Known common system and popular utility global hotkeys
    private let knownConflicts: [String: String] = [
        "⌘Space": "macOS Spotlight Search",
        "⌃Space": "macOS Input Source Switcher",
        "⌘Tab": "macOS Application Switcher",
        "⌥R": "Screen Recording / Replay Utility",
        "⌥D": "macOS Dock Auto-Hide Toggle",
        "⌘⇧3": "macOS Fullscreen Screenshot",
        "⌘⇧4": "macOS Area Screenshot",
        "⌘⇧5": "macOS Screen Recording Palette"
    ]
    
    /// Detects if a shortcut has known system or popular conflicts
    public func checkConflict(for shortcut: String) -> ShortcutConflict? {
        let normalized = shortcut.trimmingCharacters(in: .whitespaces)
        
        if let existing = knownConflicts[normalized] {
            return ShortcutConflict(
                shortcut: normalized,
                conflictingAppOrFeature: existing,
                severity: .warning,
                recommendation: "Another feature (\(existing)) already uses \"\(normalized)\". Choose a different shortcut or keep both."
            )
        }
        
        return nil
    }
}
