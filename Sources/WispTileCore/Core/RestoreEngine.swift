import Foundation
import AppKit
import CoreGraphics
@preconcurrency import ApplicationServices

public struct RestoreReportItem: Sendable {
    public let appName: String
    public let bundleId: String
    public let status: String // "Restored", "Needs you", "Skipped"
    public let detail: String
    public let targetFrame: CGRect
    public let actualFrame: CGRect?
    public let isReused: Bool

    public init(appName: String, bundleId: String, status: String, detail: String, targetFrame: CGRect, actualFrame: CGRect?, isReused: Bool) {
        self.appName = appName
        self.bundleId = bundleId
        self.status = status
        self.detail = detail
        self.targetFrame = targetFrame
        self.actualFrame = actualFrame
        self.isReused = isReused
    }
}

public struct RestoreReport: Sendable {
    public let projectId: UUID
    public let projectName: String
    public let duration: TimeInterval
    public let items: [RestoreReportItem]
    public let successCount: Int
    public let warningCount: Int
    public let skippedCount: Int
    public let snapshot: Snapshot
    public let passed: Bool

    public init(projectId: UUID, projectName: String, duration: TimeInterval, items: [RestoreReportItem], successCount: Int, warningCount: Int, skippedCount: Int, snapshot: Snapshot, passed: Bool) {
        self.projectId = projectId
        self.projectName = projectName
        self.duration = duration
        self.items = items
        self.successCount = successCount
        self.warningCount = warningCount
        self.skippedCount = skippedCount
        self.snapshot = snapshot
        self.passed = passed
    }
    
    public var summaryText: String {
        "\(projectName) restored in \(String(format: "%.2f", duration))s: \(successCount) Restored · \(warningCount) Need you · \(skippedCount) Skipped"
    }
}

@MainActor
public final class RestoreEngine {
    public static let shared = RestoreEngine()
    
    private let windowManager = WindowManager.shared
    private let displayManager = DisplayManager.shared
    private let appLauncher = AppLauncher.shared
    private let tilingEngine = TilingEngine.shared
    private let snapshotEngine = SnapshotEngine.shared
    private let rulesEngine = RulesEngine.shared
    private let storageEngine = StorageEngine.shared
    private let compatibilityEngine = CompatibilityEngine.shared
    private let diagnosticsEngine = DiagnosticsEngine.shared
    
    public init() {}
    
    /// The window a project item should use: same app, standard, not already used by another item.
    /// With `preferNotIn`, a window that wasn't open before (a freshly launched one) wins.
    static func pickWindow(for item: ProjectItem, in windows: [WindowModel], claimed: Set<CGWindowID>, preferNotIn initial: Set<CGWindowID>?) -> WindowModel? {
        let candidates = windows.filter {
            ($0.bundleId?.caseInsensitiveCompare(item.bundleId) == .orderedSame ||
             $0.appName.caseInsensitiveCompare(item.appName) == .orderedSame) &&
            $0.isStandardWindow && !claimed.contains($0.id)
        }
        if let initial, let fresh = candidates.first(where: { !initial.contains($0.id) }) { return fresh }
        return candidates.first
    }
    
    /// Restores a project layout across connected displays
    public func restore(project: Project) async -> RestoreReport {
        let startTime = Date()
        let displays = displayManager.getDisplays()
        let currentSignature = DisplaySignature(screens: displays)
        
        // 1. Take automatic pre-restore snapshot
        let snapshot = snapshotEngine.createSnapshot(
            name: "Before restoring \(project.name)",
            kind: .autoBeforeRestore,
            sourceProject: project
        )
        
        // 2. Select layout matching display setup or fallback
        let layout = project.layouts[currentSignature.rawValue] ??
                     project.layouts.values.first(where: { $0.displaySignature.screenCount == displays.count }) ??
                     project.layouts.values.first
        
        // Projects without a saved layout still restore from their items' own positions.
        let activeLayout = layout
        guard !displays.isEmpty else {
            return RestoreReport(
                projectId: project.id,
                projectName: project.name,
                duration: 0,
                items: [],
                successCount: 0,
                warningCount: 0,
                skippedCount: 0,
                snapshot: snapshot,
                passed: false
            )
        }
        
        // 3. Inspect currently open windows
        let initialWindows = windowManager.getVisibleWindows()
        let preCounts = Dictionary(grouping: initialWindows, by: { $0.bundleId ?? "" }).mapValues { $0.count }
        
        let initialIDs = Set(initialWindows.map(\.id))
        var claimed = Set<CGWindowID>() // each saved item gets its own window
        var reportItems: [RestoreReportItem] = []
        var successCount = 0
        var warningCount = 0
        var skippedCount = 0
        
        let template = TemplateEngine.shared.template(id: project.layoutTemplateId)
        for (itemIndex, item) in project.items.enumerated() {
            // Check compatibility, call protection & fixed dialogs
            let eval = compatibilityEngine.evaluateWindow(
                appName: item.appName,
                bundleId: item.bundleId,
                windowTitle: nil,
                isResizable: true
            )
            
            if eval.isCallProtected || (project.restoreOptions.protectCallWindows && rulesEngine.isCallApp(bundleId: item.bundleId, appName: item.appName)) {
                let targetDisplay = displays.indices.contains(item.displayIndex) ? displays[item.displayIndex] : displays[0]
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Skipped",
                    detail: eval.skipReason ?? "Skipped on purpose: Call protection rule active",
                    targetFrame: targetDisplay.axVisibleFrame,
                    actualFrame: nil,
                    isReused: true
                ))
                skippedCount += 1
                continue
            }
            
            if rulesEngine.isNeverTileApp(bundleId: item.bundleId, appName: item.appName) {
                let targetDisplay = displays.indices.contains(item.displayIndex) ? displays[item.displayIndex] : displays[0]
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Skipped",
                    detail: "Skipped on purpose: excluded by your rules",
                    targetFrame: targetDisplay.axVisibleFrame,
                    actualFrame: nil,
                    isReused: true
                ))
                skippedCount += 1
                continue
            }
            
            if !eval.shouldTile, let reason = eval.skipReason {
                let targetDisplay = displays.indices.contains(item.displayIndex) ? displays[item.displayIndex] : displays[0]
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Skipped",
                    detail: "Skipped on purpose: \(reason)",
                    targetFrame: targetDisplay.axVisibleFrame,
                    actualFrame: nil,
                    isReused: true
                ))
                skippedCount += 1
                continue
            }
            
            let targetDisplay = displays.indices.contains(item.displayIndex) ? displays[item.displayIndex] : displays[0]
            
            let targetFrame = tilingEngine.restoreFrame(for: item, layout: activeLayout, on: targetDisplay,
                                                         template: template, index: itemIndex).frame
            
            // Check if an unclaimed window of this app is already open
            let hasExistingWindow = Self.pickWindow(for: item, in: initialWindows, claimed: claimed, preferNotIn: nil) != nil
            
            var targetURL: URL? = nil
            if let path = item.pathOrURL, !path.isEmpty {
                if path.starts(with: "/") || path.starts(with: "~") {
                    let expanded = NSString(string: path).expandingTildeInPath
                    targetURL = URL(fileURLWithPath: expanded)
                } else if path.starts(with: "http://") || path.starts(with: "https://") {
                    targetURL = URL(string: path)
                }
            }
            
            // Launch or activate
            do {
                _ = try await appLauncher.launchOrActivate(
                    bundleId: item.bundleId,
                    appName: item.appName,
                    targetURL: targetURL,
                    hasExistingWindow: (item.launchBehavior == .reuseWindow) && hasExistingWindow
                )
            } catch {
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Needs you",
                    detail: "Could not launch: \(error.localizedDescription)",
                    targetFrame: targetFrame,
                    actualFrame: nil,
                    isReused: false
                ))
                warningCount += 1
                continue
            }
            
            // Wait briefly for window mapping. A reused item takes an existing window; a newly
            // opened one prefers a window that wasn't there before, so two items never share a window.
            let reusing = item.launchBehavior == .reuseWindow && hasExistingWindow
            var targetWindow: WindowModel?
            for attempt in 0..<15 {
                let currentWindows = windowManager.getVisibleWindows()
                let preferNew: Set<CGWindowID>? = reusing ? nil : initialIDs
                if let match = Self.pickWindow(for: item, in: currentWindows, claimed: claimed, preferNotIn: preferNew),
                   reusing || !initialIDs.contains(match.id) || attempt >= 8 {
                    targetWindow = match
                    break
                }
                try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
            }
            if let w = targetWindow { claimed.insert(w.id) }
            
            guard let window = targetWindow, let ax = window.axElement else {
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Needs you",
                    detail: "App running but no standard window was detected",
                    targetFrame: targetFrame,
                    actualFrame: nil,
                    isReused: hasExistingWindow
                ))
                warningCount += 1
                continue
            }
            
            // Move and resize window
            let moveResult = windowManager.setWindowFrame(ax, to: targetFrame)
            
            switch moveResult {
            case .success(let actualFrame):
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Restored",
                    detail: hasExistingWindow ? "Reused existing window in \(item.zoneId ?? "Zone")" : "Launched and placed in \(item.zoneId ?? "Zone")",
                    targetFrame: targetFrame,
                    actualFrame: actualFrame,
                    isReused: hasExistingWindow
                ))
                successCount += 1
                
            case .partial(let actualFrame, let reason):
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Restored",
                    detail: "Placed with constraints: \(reason)",
                    targetFrame: targetFrame,
                    actualFrame: actualFrame,
                    isReused: hasExistingWindow
                ))
                successCount += 1
                
            case .failed(let error):
                reportItems.append(RestoreReportItem(
                    appName: item.appName,
                    bundleId: item.bundleId,
                    status: "Needs you",
                    detail: "Failed to set frame: \(error)",
                    targetFrame: targetFrame,
                    actualFrame: nil,
                    isReused: hasExistingWindow
                ))
                warningCount += 1
            }
        }
        
        // Verify duplicate check
        let postWindows = windowManager.getVisibleWindows()
        let postCounts = Dictionary(grouping: postWindows, by: { $0.bundleId ?? "" }).mapValues { $0.count }
        
        var noDuplicates = true
        for item in project.items where item.launchBehavior == .reuseWindow {
            let pre = preCounts[item.bundleId] ?? 0
            let post = postCounts[item.bundleId] ?? 0
            if pre > 0 && post > pre {
                noDuplicates = false
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let passed = (successCount >= project.items.count) && noDuplicates
        
        diagnosticsEngine.recordRestoreCompleted()
        diagnosticsEngine.logEvent("Project '\(project.name)' restore finished in \(String(format: "%.2f", duration))s: \(successCount) restored, \(warningCount) warnings, \(skippedCount) skipped.")
        
        return RestoreReport(
            projectId: project.id,
            projectName: project.name,
            duration: duration,
            items: reportItems,
            successCount: successCount,
            warningCount: warningCount,
            skippedCount: skippedCount,
            snapshot: snapshot,
            passed: passed
        )
    }
}
