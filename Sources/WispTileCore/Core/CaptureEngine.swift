import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices

public struct CapturedWindow: Identifiable, Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let bundleId: String
    public let title: String
    public let displayIndex: Int
    public let relativeRect: CGRect
    public let detectedPathOrURL: String?
    public let isCallApp: Bool
    public var isSelected: Bool
}

@MainActor
public final class CaptureEngine {
    public static let shared = CaptureEngine()
    
    private let windowManager = WindowManager.shared
    private let displayManager = DisplayManager.shared
    private let rulesEngine = RulesEngine.shared
    
    public init() {}
    
    /// Inspects all currently open windows and prepares them for project capture
    public func scanDesktop() -> (windows: [CapturedWindow], displays: [DisplayInfo]) {
        let liveWindows = windowManager.getVisibleWindows()
        let displays = displayManager.getDisplays()
        
        var captured: [CapturedWindow] = []
        
        let ownBundle = Bundle.main.bundleIdentifier
        for w in liveWindows where w.bundleId == nil || w.bundleId != ownBundle {
            let bundleId = w.bundleId ?? "unknown.\(w.appName.lowercased())"
            let excluded = StorageEngine.shared.loadSettings().excludedApps
            let isCall = rulesEngine.isCallApp(bundleId: bundleId, appName: w.appName, title: w.title)
                || excluded.appNames.contains(w.appName) || excluded.bundleIds.contains(bundleId)
            
            // Find which display contains the window center
            let windowCenter = CGPoint(x: w.frame.midX, y: w.frame.midY)
            var targetDisplayIndex = 0
            for (idx, d) in displays.enumerated() {
                if d.axFrame.contains(windowCenter) {
                    targetDisplayIndex = idx
                    break
                }
            }
            
            let display = displays.indices.contains(targetDisplayIndex) ? displays[targetDisplayIndex] : (displays.first ?? DisplayInfo(
                id: 1, name: "Screen", isPrimary: true, isBuiltIn: true, hasNotch: false, safeAreaTopInset: 0,
                cocoaFrame: w.frame, cocoaVisibleFrame: w.frame, axFrame: w.frame, axVisibleFrame: w.frame
            ))
            
            // Compute relative normalized rect inside the usable visible frame
            let relativeRect = Self.relativeRect(of: w.frame, in: display.axVisibleFrame)
            
            // Extract document path or folder from title if available
            let detectedPath = extractPathOrURL(appName: w.appName, title: w.title)
            
            captured.append(CapturedWindow(
                id: w.id,
                pid: w.pid,
                appName: w.appName,
                bundleId: bundleId,
                title: w.title,
                displayIndex: targetDisplayIndex,
                relativeRect: relativeRect,
                detectedPathOrURL: detectedPath,
                isCallApp: isCall,
                isSelected: !isCall // Auto-select regular windows, deselect call apps by default
            ))
        }
        
        return (captured, displays)
    }
    
    /// Creates a complete Project entity from the selected captured windows
    /// A window frame as fractions (0…1, 3 decimals) of a display's usable area.
    public static func relativeRect(of frame: CGRect, in vis: CGRect) -> CGRect {
        let relX = max(0.0, min(1.0, (frame.origin.x - vis.origin.x) / max(1, vis.width)))
        let relY = max(0.0, min(1.0, (frame.origin.y - vis.origin.y) / max(1, vis.height)))
        let relW = max(0.05, min(1.0, frame.width / max(1, vis.width)))
        let relH = max(0.05, min(1.0, frame.height / max(1, vis.height)))
        return CGRect(
            x: (relX * 1000).rounded() / 1000,
            y: (relY * 1000).rounded() / 1000,
            width: (relW * 1000).rounded() / 1000,
            height: (relH * 1000).rounded() / 1000
        )
    }
    
    public func captureProject(
        name: String,
        colorHex: String = "#4A2FC4",
        shortcut: String? = nil,
        selectedWindows: [CapturedWindow],
        template: Template? = nil
    ) -> Project {
        let displays = displayManager.getDisplays()
        let signature = DisplaySignature(screens: displays)
        
        var projectItems: [ProjectItem] = []
        var displayZones: [Int: [Zone]] = [:]
        var zoneAssignments: [String: [UUID]] = [:]
        
        for (i, w) in selectedWindows.enumerated() {
            let itemId = UUID()
            let zoneId = "zone_\(i + 1)"
            
            let item = ProjectItem(
                id: itemId,
                appName: w.appName,
                bundleId: w.bundleId,
                pathOrURL: w.detectedPathOrURL,
                displayIndex: w.displayIndex,
                zoneId: zoneId,
                customRelativeRect: w.relativeRect,
                launchBehavior: .reuseWindow
            )
            projectItems.append(item)
            
            // Generate a zone matching the window position
            let zone = Zone(
                id: zoneId,
                name: "\(w.appName) Zone",
                relativeRect: w.relativeRect,
                defaultAppBundleId: w.bundleId
            )
            
            var zonesForDisplay = displayZones[w.displayIndex] ?? []
            zonesForDisplay.append(zone)
            displayZones[w.displayIndex] = zonesForDisplay
            zoneAssignments[zoneId] = [itemId]
        }
        
        let layout = ProjectLayout(
            displaySignature: signature,
            templateId: template?.id,
            displayZones: displayZones,
            zoneAssignments: zoneAssignments
        )
        
        let project = Project(
            name: name,
            colorHex: colorHex,
            shortcut: shortcut,
            items: projectItems,
            layouts: [signature.rawValue: layout],
            restoreOptions: .default
        )
        
        return project
    }
    
    private func extractPathOrURL(appName: String, title: String) -> String? {
        if title.isEmpty { return nil }
        
        // Check for file paths starting with / or ~
        if title.starts(with: "/") || title.starts(with: "~") {
            let parts = title.components(separatedBy: " ")
            return parts.first
        }
        
        // Check for URL or localhost
        if title.contains("localhost:") || title.contains("http://") || title.contains("https://") {
            let parts = title.components(separatedBy: " ")
            for p in parts {
                if p.contains("localhost:") || p.starts(with: "http://") || p.starts(with: "https://") {
                    return p
                }
            }
        }
        
        // Check for editor patterns: "filename — projectFolder" or "saas-app — main.swift"
        if title.contains(" — ") {
            let parts = title.components(separatedBy: " — ")
            return parts.last?.trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
}
