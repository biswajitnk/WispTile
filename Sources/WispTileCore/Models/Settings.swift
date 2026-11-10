import Foundation
import CoreGraphics

public struct WispTileSettings: Codable, Equatable, Sendable {
    // General
    public var launchAtLogin: Bool
    public var showInMenuBar: Bool
    public var showInDock: Bool
    
    // Tiling & Spacing Geometry
    public var gapBetweenWindows: CGFloat
    public var screenEdgePadding: CGFloat
    public var animateSnapping: Bool
    
    // Tiling Behaviors
    public var autoTileNewWindows: Bool
    public var snapWhileDragging: Bool
    public var retileAfterDisplayChange: Bool
    
    // Safety
    public var excludedApps: ExcludedApps
    
    // Global Shortcuts
    public var quickSwitcherShortcut: String
    public var captureShortcut: String
    public var repairShortcut: String
    
    // Appearance (Board 18)
    public var appearance: String // "Light", "Dark", "Auto"
    
    // Notifications (Board 18)
    public var notifyOnRestoreResults: Bool
    public var notifyOnDriftAlerts: Bool
    public var notifyOnAppUpdates: Bool
    
    // Privacy and Data (Board 18 & PRD: off by default)
    public var shareAnonymousUsageData: Bool
    
    // Update Settings (Board 10 & 11)
    public var automaticallyCheckForUpdates: Bool
    public var notifyWhenAppIsClosed: Bool
    public var automaticallyInstallUpdates: Bool
    
    // User profile
    public var userName: String
    public var userEmail: String
    
    public init(
        launchAtLogin: Bool = true,
        showInMenuBar: Bool = true,
        showInDock: Bool = true,
        gapBetweenWindows: CGFloat = 8.0,
        screenEdgePadding: CGFloat = 12.0,
        animateSnapping: Bool = true,
        autoTileNewWindows: Bool = false,
        snapWhileDragging: Bool = true,
        retileAfterDisplayChange: Bool = true,
        excludedApps: ExcludedApps = .defaults,
        quickSwitcherShortcut: String = "⌃⌥Space",
        captureShortcut: String = "⌃⌥C",
        repairShortcut: String = "⌃⌥R",
        appearance: String = "Auto",
        notifyOnRestoreResults: Bool = true,
        notifyOnDriftAlerts: Bool = true,
        notifyOnAppUpdates: Bool = true,
        shareAnonymousUsageData: Bool = false,
        automaticallyCheckForUpdates: Bool = true,
        notifyWhenAppIsClosed: Bool = true,
        automaticallyInstallUpdates: Bool = false,
        userName: String = "Your Name",
        userEmail: String = "you@example.com"
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.showInDock = showInDock
        self.gapBetweenWindows = gapBetweenWindows
        self.screenEdgePadding = screenEdgePadding
        self.animateSnapping = animateSnapping
        self.autoTileNewWindows = autoTileNewWindows
        self.snapWhileDragging = snapWhileDragging
        self.retileAfterDisplayChange = retileAfterDisplayChange
        self.excludedApps = excludedApps
        self.quickSwitcherShortcut = quickSwitcherShortcut
        self.captureShortcut = captureShortcut
        self.repairShortcut = repairShortcut
        self.appearance = appearance
        self.notifyOnRestoreResults = notifyOnRestoreResults
        self.notifyOnDriftAlerts = notifyOnDriftAlerts
        self.notifyOnAppUpdates = notifyOnAppUpdates
        self.shareAnonymousUsageData = shareAnonymousUsageData
        self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
        self.notifyWhenAppIsClosed = notifyWhenAppIsClosed
        self.automaticallyInstallUpdates = automaticallyInstallUpdates
        self.userName = userName
        self.userEmail = userEmail
    }
    
    public static let `default` = WispTileSettings()
}
