import Foundation
import CoreGraphics

public enum AppCategory: String, Sendable, Codable, CaseIterable {
    case browser = "Browser"
    case codeEditor = "Code Editor"
    case terminal = "Terminal"
    case electron = "Electron App"
    case callApp = "Call / Meeting App"
    case system = "macOS System"
    case general = "General App"
}

public struct AppCompatibilityProfile: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let bundleId: String
    public let category: AppCategory
    public let supportsFolderLaunch: Bool
    public let supportsURLRestore: Bool
    public let multiProfileCapable: Bool
    public let neverTileByDefault: Bool
    public let notes: String
    
    public init(
        name: String,
        bundleId: String,
        category: AppCategory,
        supportsFolderLaunch: Bool = false,
        supportsURLRestore: Bool = false,
        multiProfileCapable: Bool = false,
        neverTileByDefault: Bool = false,
        notes: String = ""
    ) {
        self.id = bundleId
        self.name = name
        self.bundleId = bundleId
        self.category = category
        self.supportsFolderLaunch = supportsFolderLaunch
        self.supportsURLRestore = supportsURLRestore
        self.multiProfileCapable = multiProfileCapable
        self.neverTileByDefault = neverTileByDefault
        self.notes = notes
    }
}

/// Comprehensive engine managing macOS application compatibility, active call safety, and non-standard window handling
public final class CompatibilityEngine: @unchecked Sendable {
    public static let shared = CompatibilityEngine()
    
    private let profiles: [String: AppCompatibilityProfile]
    
    public init() {
        var map: [String: AppCompatibilityProfile] = [:]
        
        let builtIns: [AppCompatibilityProfile] = [
            // Browsers
            AppCompatibilityProfile(name: "Google Chrome", bundleId: "com.google.Chrome", category: .browser, supportsURLRestore: true, multiProfileCapable: true, notes: "Full tab and multi-profile restore support"),
            AppCompatibilityProfile(name: "Safari", bundleId: "com.apple.Safari", category: .browser, supportsURLRestore: true, multiProfileCapable: true, notes: "Native AppleScript and URL restore"),
            AppCompatibilityProfile(name: "Brave Browser", bundleId: "com.brave.Browser", category: .browser, supportsURLRestore: true, multiProfileCapable: true, notes: "Chromium multi-profile restore"),
            AppCompatibilityProfile(name: "Arc", bundleId: "company.thebrowser.Browser", category: .browser, supportsURLRestore: true, multiProfileCapable: true, notes: "Space and tab navigation awareness"),
            AppCompatibilityProfile(name: "Microsoft Edge", bundleId: "com.microsoft.edgemac", category: .browser, supportsURLRestore: true, multiProfileCapable: true, notes: "Edge profiles and URL routing"),
            AppCompatibilityProfile(name: "Mozilla Firefox", bundleId: "org.mozilla.firefox", category: .browser, supportsURLRestore: true, multiProfileCapable: false, notes: "Standard window restore"),
            
            // Code Editors & IDEs
            AppCompatibilityProfile(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode", category: .codeEditor, supportsFolderLaunch: true, notes: "Re-opens workspace folder without duplicate windows"),
            AppCompatibilityProfile(name: "Cursor", bundleId: "com.todesktop.230313mzl4w4u92", category: .codeEditor, supportsFolderLaunch: true, notes: "Cursor AI editor workspace restore"),
            AppCompatibilityProfile(name: "Xcode", bundleId: "com.apple.dt.Xcode", category: .codeEditor, supportsFolderLaunch: true, notes: "Project/workspace opening via open URL"),
            AppCompatibilityProfile(name: "Sublime Text", bundleId: "com.sublimetext.4", category: .codeEditor, supportsFolderLaunch: true, notes: "Folder project restoration"),
            AppCompatibilityProfile(name: "IntelliJ IDEA", bundleId: "com.jetbrains.intellij", category: .codeEditor, supportsFolderLaunch: true, notes: "JetBrains project folder reuse"),
            AppCompatibilityProfile(name: "Android Studio", bundleId: "com.google.android.studio", category: .codeEditor, supportsFolderLaunch: true, notes: "Android Studio project restore"),
            
            // Terminals
            AppCompatibilityProfile(name: "Terminal", bundleId: "com.apple.Terminal", category: .terminal, supportsFolderLaunch: true, notes: "Native terminal folder navigation"),
            AppCompatibilityProfile(name: "iTerm2", bundleId: "com.googlecode.iterm2", category: .terminal, supportsFolderLaunch: true, notes: "Tab and directory reuse"),
            AppCompatibilityProfile(name: "Warp", bundleId: "dev.warp.Warp-Stable", category: .terminal, supportsFolderLaunch: true, notes: "Modern Rust-based terminal"),
            AppCompatibilityProfile(name: "Alacritty", bundleId: "org.alacritty", category: .terminal, supportsFolderLaunch: true, notes: "GPU accelerated terminal"),
            
            // Electron & Modern Workspace Apps
            AppCompatibilityProfile(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", category: .electron, notes: "Single window workspace; helper renderer processes isolated"),
            AppCompatibilityProfile(name: "Obsidian", bundleId: "md.obsidian", category: .electron, supportsFolderLaunch: true, notes: "Vault directory auto-load"),
            AppCompatibilityProfile(name: "Discord", bundleId: "com.hnc.Discord", category: .electron, notes: "Main voice/chat window tiling"),
            AppCompatibilityProfile(name: "Notion", bundleId: "notion.id", category: .electron, notes: "Workspace window matching"),
            AppCompatibilityProfile(name: "Spotify", bundleId: "com.spotify.client", category: .electron, notes: "Player window positioning"),
            AppCompatibilityProfile(name: "Figma", bundleId: "com.figma.Desktop", category: .electron, notes: "Canvas tab preservation"),
            
            // Active Call Protection Apps
            AppCompatibilityProfile(name: "Zoom", bundleId: "us.zoom.xos", category: .callApp, neverTileByDefault: true, notes: "Protected from auto-tiling during active meetings"),
            AppCompatibilityProfile(name: "FaceTime", bundleId: "com.apple.FaceTime", category: .callApp, neverTileByDefault: true, notes: "Protected from auto-tiling during calls"),
            AppCompatibilityProfile(name: "Microsoft Teams", bundleId: "com.microsoft.teams2", category: .callApp, neverTileByDefault: false, notes: "Meeting windows protected; chat windows tileable"),
            AppCompatibilityProfile(name: "Cisco Webex", bundleId: "com.cisco.webexmeetingsapp", category: .callApp, neverTileByDefault: true, notes: "Protected during conference calls"),
            
            // macOS System Apps
            AppCompatibilityProfile(name: "Finder", bundleId: "com.apple.finder", category: .system, supportsFolderLaunch: true, notes: "Folder browsing and tab restoration"),
            AppCompatibilityProfile(name: "System Settings", bundleId: "com.apple.systempreferences", category: .system, neverTileByDefault: true, notes: "Fixed-size window; excluded from tiling"),
            AppCompatibilityProfile(name: "Activity Monitor", bundleId: "com.apple.ActivityMonitor", category: .system, notes: "Utility diagnostics window")
        ]
        
        for p in builtIns {
            map[p.bundleId.lowercased()] = p
        }
        self.profiles = map
    }
    
    /// Finds compatibility profile by bundle identifier or localized name
    public func profile(forBundleId bundleId: String?, appName: String? = nil) -> AppCompatibilityProfile? {
        if let bundleId = bundleId?.lowercased(), let match = profiles[bundleId] {
            return match
        }
        if let appName = appName?.lowercased() {
            return profiles.values.first { $0.name.lowercased() == appName }
        }
        return nil
    }
    
    // MARK: - Active Call Protection (App Store Safety & Zero User Interruption)
    
    /// Determines if a window is part of an active voice or video call
    public func isCallActive(bundleId: String?, windowTitle: String?) -> Bool {
        guard let bundleId = bundleId?.lowercased() else { return false }
        let title = windowTitle?.lowercased() ?? ""
        
        // Zoom
        if bundleId.contains("zoom") {
            if title.contains("meeting") || title.contains("webinar") || title.contains("zoom meeting") {
                return true
            }
        }
        
        // FaceTime
        if bundleId.contains("facetime") {
            if !title.isEmpty && !title.contains("facetime history") {
                return true
            }
        }
        
        // Google Meet (Running in Chrome, Arc, Brave, Safari)
        if title.contains("meet - ") || title.contains("meet: ") || title.contains("google meet") {
            return true
        }
        
        // Microsoft Teams
        if bundleId.contains("teams") {
            if title.contains("meeting") || title.contains("call with") || title.contains("teams meeting") {
                return true
            }
        }
        
        // Cisco Webex
        if bundleId.contains("webex") {
            if title.contains("meeting") || title.contains("call") {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Fixed & Stubborn Window Detection
    
    public struct WindowEvaluation: Sendable {
        public let shouldTile: Bool
        public let skipReason: String?
        public let isCallProtected: Bool
    }
    
    /// Evaluates whether a window should be tiled or safely skipped
    public func evaluateWindow(
        appName: String,
        bundleId: String?,
        windowTitle: String?,
        isResizable: Bool = true
    ) -> WindowEvaluation {
        // 1. Check Active Call Protection
        if isCallActive(bundleId: bundleId, windowTitle: windowTitle) {
            return WindowEvaluation(
                shouldTile: false,
                skipReason: "Active video/voice call protected from disruption",
                isCallProtected: true
            )
        }
        
        // 2. Check System Settings & Dialogs
        if bundleId?.lowercased() == "com.apple.systempreferences" {
            return WindowEvaluation(
                shouldTile: false,
                skipReason: "System Settings is a fixed utility window",
                isCallProtected: false
            )
        }
        
        // 3. Check Preferences / Modal sheets
        let title = windowTitle?.lowercased() ?? ""
        if title.hasPrefix("preferences") || title.hasPrefix("settings") || title.contains("quick look") || title.hasPrefix("about ") {
            return WindowEvaluation(
                shouldTile: false,
                skipReason: "Preferences or modal dialog window",
                isCallProtected: false
            )
        }
        
        // 4. Check Non-resizable windows
        if !isResizable {
            return WindowEvaluation(
                shouldTile: false,
                skipReason: "Window does not support resize via Accessibility",
                isCallProtected: false
            )
        }
        
        // 5. Check Never-tile profile setting
        if let prof = profile(forBundleId: bundleId, appName: appName), prof.neverTileByDefault {
            return WindowEvaluation(
                shouldTile: false,
                skipReason: "\(prof.name) is configured to float by default",
                isCallProtected: false
            )
        }
        
        return WindowEvaluation(shouldTile: true, skipReason: nil, isCallProtected: false)
    }
    
    // MARK: - Compatibility Matrix Audit
    
    public func auditCompatibilityMatrix() -> (totalProfiles: Int, categories: [AppCategory: Int]) {
        var breakdown: [AppCategory: Int] = [:]
        for cat in AppCategory.allCases {
            breakdown[cat] = 0
        }
        for p in profiles.values {
            breakdown[p.category, default: 0] += 1
        }
        return (profiles.count, breakdown)
    }
}
