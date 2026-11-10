import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices

public struct DriftedWindow: Identifiable, Sendable {
    public var id: CGWindowID { windowId }
    public let windowId: CGWindowID
    public let appName: String
    public let bundleId: String?
    public let title: String
    public let zoneId: String
    public let zoneName: String
    public let targetFrame: CGRect
    public let currentFrame: CGRect
    public let deltaXPercent: CGFloat
    public let deltaYPercent: CGFloat
    public let deltaWPercent: CGFloat
    public let deltaHPercent: CGFloat
    public let driftDescription: String
    public let isWrongDisplay: Bool
}

public struct DriftReport: Sendable {
    public let projectId: UUID
    public let projectName: String
    public let driftedWindows: [DriftedWindow]
    public let totalWindowsChecked: Int
    public let hasDrift: Bool
    public let timestamp: Date
}

public extension DriftedWindow {
    init(windowId: CGWindowID, appName: String, bundleId: String?, title: String, zoneId: String, zoneName: String,
         targetFrame: CGRect, currentFrame: CGRect, driftDescription: String, isWrongDisplay: Bool) {
        self.windowId = windowId; self.appName = appName; self.bundleId = bundleId; self.title = title
        self.zoneId = zoneId; self.zoneName = zoneName; self.targetFrame = targetFrame; self.currentFrame = currentFrame
        let w = max(1, targetFrame.width), h = max(1, targetFrame.height)
        self.deltaXPercent = (currentFrame.minX - targetFrame.minX) / w * 100
        self.deltaYPercent = (currentFrame.minY - targetFrame.minY) / h * 100
        self.deltaWPercent = (currentFrame.width - targetFrame.width) / w * 100
        self.deltaHPercent = (currentFrame.height - targetFrame.height) / h * 100
        self.driftDescription = driftDescription; self.isWrongDisplay = isWrongDisplay
    }
}

public extension DriftReport {
    init(projectId: UUID, projectName: String, driftedWindows: [DriftedWindow], totalWindowsChecked: Int) {
        self.projectId = projectId; self.projectName = projectName; self.driftedWindows = driftedWindows
        self.totalWindowsChecked = totalWindowsChecked; self.hasDrift = !driftedWindows.isEmpty; self.timestamp = Date()
    }
}

@MainActor
public final class DriftEngine {
    public static let shared = DriftEngine()
    
    private let windowManager = WindowManager.shared
    private let displayManager = DisplayManager.shared
    private let tilingEngine = TilingEngine.shared
    private let storageEngine = StorageEngine.shared
    private let rulesEngine = RulesEngine.shared
    
    public init() {}
    
    /// Detects whether live open windows have drifted away from a project's saved layout
    public func detectDrift(for project: Project) -> DriftReport {
        let displays = displayManager.getDisplays()
        let currentSignature = DisplaySignature(screens: displays)
        
        let layout = project.layouts[currentSignature.rawValue] ??
                     project.layouts.values.first(where: { $0.displaySignature.screenCount == displays.count }) ??
                     project.layouts.values.first
        
        guard let activeLayout = layout, !displays.isEmpty else {
            return DriftReport(
                projectId: project.id,
                projectName: project.name,
                driftedWindows: [],
                totalWindowsChecked: 0,
                hasDrift: false,
                timestamp: Date()
            )
        }
        
        let liveWindows = windowManager.getVisibleWindows()
        var drifted: [DriftedWindow] = []
        var checkedCount = 0
        
        let template = TemplateEngine.shared.template(id: project.layoutTemplateId)
        for (itemIndex, item) in project.items.enumerated() {
            // Skip excluded call windows
            if rulesEngine.isCallApp(bundleId: item.bundleId, appName: item.appName) {
                continue
            }
            
            // Find live window matching this project item
            guard let liveMatch = liveWindows.first(where: {
                ($0.bundleId?.caseInsensitiveCompare(item.bundleId) == .orderedSame ||
                 $0.appName.caseInsensitiveCompare(item.appName) == .orderedSame) &&
                $0.isStandardWindow
            }) else {
                continue
            }
            
            checkedCount += 1
            let targetDisplay = displays.indices.contains(item.displayIndex) ? displays[item.displayIndex] : displays[0]
            
            // Resolve target zone (same rule as restore, so a just-restored workspace never reads as drifted)
            let (targetFrame, zoneName) = tilingEngine.restoreFrame(for: item, layout: activeLayout, on: targetDisplay,
                                                                    template: template, index: itemIndex)
            let currentFrame = liveMatch.frame
            
            // Check if window is on a completely wrong display
            let center = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
            let isWrongDisplay = !targetDisplay.axFrame.contains(center)
            
            // Compute percentage differences relative to display bounds
            let dx = abs(currentFrame.origin.x - targetFrame.origin.x)
            let dy = abs(currentFrame.origin.y - targetFrame.origin.y)
            let dw = abs(currentFrame.size.width - targetFrame.size.width)
            let dh = abs(currentFrame.size.height - targetFrame.size.height)
            
            let dxPercent = dx / max(1, targetDisplay.axVisibleFrame.width)
            let dyPercent = dy / max(1, targetDisplay.axVisibleFrame.height)
            let dwPercent = dw / max(1, targetDisplay.axVisibleFrame.width)
            let dhPercent = dh / max(1, targetDisplay.axVisibleFrame.height)
            
            // Drift threshold: moved > 4% of display or wrong display
            if dxPercent > 0.04 || dyPercent > 0.04 || dwPercent > 0.05 || dhPercent > 0.05 || isWrongDisplay {
                let description: String
                if isWrongDisplay {
                    description = "Opened on wrong display (expected on \(targetDisplay.name))"
                } else {
                    let pct = Int(max(dxPercent, max(dyPercent, max(dwPercent, dhPercent))) * 100)
                    description = "Shifted or resized by ~\(pct)% from \(zoneName)"
                }
                
                drifted.append(DriftedWindow(
                    windowId: liveMatch.id,
                    appName: item.appName,
                    bundleId: item.bundleId,
                    title: liveMatch.title,
                    zoneId: item.zoneId ?? "zone",
                    zoneName: zoneName,
                    targetFrame: targetFrame,
                    currentFrame: currentFrame,
                    deltaXPercent: dxPercent,
                    deltaYPercent: dyPercent,
                    deltaWPercent: dwPercent,
                    deltaHPercent: dhPercent,
                    driftDescription: description,
                    isWrongDisplay: isWrongDisplay
                ))
            }
        }
        
        return DriftReport(
            projectId: project.id,
            projectName: project.name,
            driftedWindows: drifted,
            totalWindowsChecked: checkedCount,
            hasDrift: !drifted.isEmpty,
            timestamp: Date()
        )
    }
    
    /// Snaps a single drifted window back to its target frame
    public func snapBack(windowId: CGWindowID, to targetFrame: CGRect) -> Bool {
        let liveWindows = windowManager.getVisibleWindows()
        guard let match = liveWindows.first(where: { $0.id == windowId }),
              let ax = match.axElement else {
            return false
        }
        let res = windowManager.setWindowFrame(ax, to: targetFrame)
        switch res {
        case .success, .partial:
            return true
        case .failed:
            return false
        }
    }
    
    /// Repairs all drifted windows by snapping them back
    public func repairAll(driftReport: DriftReport) -> Int {
        var repaired = 0
        for dw in driftReport.driftedWindows {
            if snapBack(windowId: dw.windowId, to: dw.targetFrame) {
                repaired += 1
            }
        }
        return repaired
    }
    
    /// Adopts the live window arrangements as the new saved layout ("Update Profile to Match")
    public func updateProjectToMatchLive(project: Project) -> Project {
        let displays = displayManager.getDisplays()
        let currentSignature = DisplaySignature(screens: displays)
        let liveWindows = windowManager.getVisibleWindows()
        
        var updatedItems = project.items
        var displayZones: [Int: [Zone]] = [:]
        var zoneAssignments: [String: [UUID]] = [:]
        
        for (i, item) in updatedItems.enumerated() {
            guard let liveMatch = liveWindows.first(where: {
                $0.bundleId?.caseInsensitiveCompare(item.bundleId) == .orderedSame ||
                $0.appName.caseInsensitiveCompare(item.appName) == .orderedSame
            }) else {
                continue
            }
            
            // Determine which display contains window center
            let center = CGPoint(x: liveMatch.frame.midX, y: liveMatch.frame.midY)
            var targetDisplayIndex = 0
            for (idx, d) in displays.enumerated() {
                if d.axFrame.contains(center) {
                    targetDisplayIndex = idx
                    break
                }
            }
            
            let display = displays.indices.contains(targetDisplayIndex) ? displays[targetDisplayIndex] : displays[0]
            let vis = display.axVisibleFrame
            let relX = max(0.0, min(1.0, (liveMatch.frame.origin.x - vis.origin.x) / max(1, vis.width)))
            let relY = max(0.0, min(1.0, (liveMatch.frame.origin.y - vis.origin.y) / max(1, vis.height)))
            let relW = max(0.05, min(1.0, liveMatch.frame.width / max(1, vis.width)))
            let relH = max(0.05, min(1.0, liveMatch.frame.height / max(1, vis.height)))
            
            let newRelativeRect = CGRect(
                x: (relX * 1000).rounded() / 1000,
                y: (relY * 1000).rounded() / 1000,
                width: (relW * 1000).rounded() / 1000,
                height: (relH * 1000).rounded() / 1000
            )
            
            updatedItems[i].displayIndex = targetDisplayIndex
            updatedItems[i].customRelativeRect = newRelativeRect
            
            let zoneId = "zone_\(i + 1)"
            let zone = Zone(id: zoneId, name: "\(item.appName) Zone", relativeRect: newRelativeRect, defaultAppBundleId: item.bundleId)
            
            var zones = displayZones[targetDisplayIndex] ?? []
            zones.append(zone)
            displayZones[targetDisplayIndex] = zones
            zoneAssignments[zoneId] = [item.id]
        }
        
        let newLayout = ProjectLayout(
            displaySignature: currentSignature,
            displayZones: displayZones,
            zoneAssignments: zoneAssignments
        )
        
        var updatedProject = project
        updatedProject.items = updatedItems
        updatedProject.layouts[currentSignature.rawValue] = newLayout
        updatedProject.updatedAt = Date()
        
        try? storageEngine.saveProject(updatedProject)
        return updatedProject
    }
}
