import Foundation
import AppKit

@MainActor
public final class AppLauncher {
    public static let shared = AppLauncher()
    
    public init() {}
    
    /// Finds a running regular application by bundleId or app name
    public func findRunningApp(bundleId: String? = nil, appName: String? = nil) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        
        if let bundleId = bundleId {
            if let match = apps.first(where: { $0.bundleIdentifier?.caseInsensitiveCompare(bundleId) == .orderedSame }) {
                return match
            }
        }
        
        if let appName = appName {
            if let match = apps.first(where: { $0.localizedName?.caseInsensitiveCompare(appName) == .orderedSame }) {
                return match
            }
        }
        
        return nil
    }
    
    /// Launches an application or activates it if already running.
    /// Guarantees window reuse: if the application already has a window, it simply activates it
    /// without creating duplicate windows.
    @discardableResult
    public func launchOrActivate(
        bundleId: String? = nil,
        appName: String? = nil,
        targetURL: URL? = nil,
        hasExistingWindow: Bool = false,
        timeoutSeconds: TimeInterval = 5.0
    ) async throws -> NSRunningApplication {
        // If app is running and already has an open window, reuse it by activating!
        if hasExistingWindow, let existing = findRunningApp(bundleId: bundleId, appName: appName) {
            existing.activate(options: [.activateIgnoringOtherApps])
            return existing
        }
        
        // If target file or folder is provided and we need to create/open a window
        if let targetURL = targetURL {
            NSWorkspace.shared.open(targetURL)
            let deadline = Date().addingTimeInterval(timeoutSeconds)
            while Date() < deadline {
                if let app = findRunningApp(bundleId: bundleId, appName: appName) {
                    app.activate(options: [.activateIgnoringOtherApps])
                    return app
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        // Finder special case: if no window exists, open home folder
        if (bundleId == "com.apple.finder" || appName?.caseInsensitiveCompare("Finder") == .orderedSame) {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            NSWorkspace.shared.open(homeURL)
            if let finder = findRunningApp(bundleId: "com.apple.finder") {
                finder.activate(options: [.activateIgnoringOtherApps])
                return finder
            }
        }
        
        // If already running, activate it
        if let existing = findRunningApp(bundleId: bundleId, appName: appName) {
            existing.activate(options: [.activateIgnoringOtherApps])
            return existing
        }
        
        // Find application URL
        var appURL: URL?
        if let bundleId = bundleId {
            appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        }
        
        if appURL == nil, let appName = appName {
            let appPath = "/System/Applications/\(appName).app"
            if FileManager.default.fileExists(atPath: appPath) {
                appURL = URL(fileURLWithPath: appPath)
            } else {
                let systemUtilPath = "/System/Applications/Utilities/\(appName).app"
                if FileManager.default.fileExists(atPath: systemUtilPath) {
                    appURL = URL(fileURLWithPath: systemUtilPath)
                } else {
                    let userAppPath = "/Applications/\(appName).app"
                    if FileManager.default.fileExists(atPath: userAppPath) {
                        appURL = URL(fileURLWithPath: userAppPath)
                    }
                }
            }
        }
        
        guard let finalURL = appURL else {
            throw NSError(
                domain: "AppLauncher",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Application not found for \(bundleId ?? appName ?? "unknown")"]
            )
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false // No duplicate instances!
        
        let launchedApp = try await NSWorkspace.shared.openApplication(at: finalURL, configuration: config)
        
        // Wait until app is ready and finished launching
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !launchedApp.isFinishedLaunching && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        return launchedApp
    }
}
