import Foundation
import CoreGraphics

public enum DisplayAdaptDecision: Sendable {
    case applyAutomatically(layout: ProjectLayout)
    case askUser(layout: ProjectLayout, message: String)
    case doNothing
}

@MainActor
public final class RulesEngine {
    public static let shared = RulesEngine()
    
    private let storageEngine = StorageEngine.shared
    
    public init() {}
    
    /// Identifies active call applications (Zoom, FaceTime, Google Meet, Slack Huddle)
    public func isCallApp(bundleId: String?, appName: String, title: String? = nil) -> Bool {
        let callBundleIds: Set<String> = [
            "us.zoom.xos",
            "com.apple.FaceTime"
        ]
        let callAppNames: Set<String> = [
            "Zoom",
            "FaceTime",
            "Google Meet"
        ]
        
        if let bundleId = bundleId, callBundleIds.contains(bundleId) {
            return true
        }
        if callAppNames.contains(appName) {
            return true
        }
        
        if let title = title?.lowercased() {
            if title.contains("google meet") || title.contains("zoom meeting") || title.contains("huddle") {
                return true
            }
        }
        
        return false
    }
    
    /// Determines whether an app is in the "Never Tile" list for auto-tiling (Calculator, System Settings, etc.)
    public func isNeverTileApp(bundleId: String?, appName: String) -> Bool {
        let settings = storageEngine.loadSettings()
        return settings.excludedApps.isExcluded(bundleId: bundleId, appName: appName)
    }
    
    /// Determines whether an app window should be excluded from automatic tiling
    public func shouldExcludeFromTiling(bundleId: String?, appName: String, title: String? = nil) -> Bool {
        return isCallApp(bundleId: bundleId, appName: appName, title: title) ||
               isNeverTileApp(bundleId: bundleId, appName: appName)
    }
    
    /// Evaluates display disconnect event against a project's layouts
    public func evaluateDisplayDisconnect(
        for project: Project,
        remainingDisplays: [DisplayInfo]
    ) -> DisplayAdaptDecision {
        let targetSignature = DisplaySignature(screens: remainingDisplays)
        
        // Look for matching laptop or fallback layout in project
        if let matchingLayout = project.layouts[targetSignature.rawValue] {
            return .applyAutomatically(layout: matchingLayout)
        }
        
        if remainingDisplays.count == 1,
           let fallback = project.layouts.values.first(where: { $0.displaySignature.screenCount == 1 }) {
            return .askUser(
                layout: fallback,
                message: "Switch \"\(project.name)\" to your laptop layout? Windows move once and nothing is closed."
            )
        }
        
        return .doNothing
    }
    
    /// Evaluates display connect event against a project's layouts
    public func evaluateDisplayConnect(
        for project: Project,
        newDisplays: [DisplayInfo]
    ) -> DisplayAdaptDecision {
        let targetSignature = DisplaySignature(screens: newDisplays)
        
        if let matchingLayout = project.layouts[targetSignature.rawValue] {
            return .askUser(
                layout: matchingLayout,
                message: "External display connected. Switch \"\(project.name)\" to your At Desk layout?"
            )
        }
        
        return .doNothing
    }
}
