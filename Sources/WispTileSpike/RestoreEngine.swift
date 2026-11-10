import Foundation
import AppKit
import CoreGraphics
@preconcurrency import ApplicationServices

public struct TargetAppZone: Sendable {
    public let appName: String
    public let bundleId: String
    public let displayIndex: Int
    public let relativeRect: CGRect // Normalized (0.0 ... 1.0)
    public let zoneName: String
    public let targetURL: URL?
    
    public init(
        appName: String,
        bundleId: String,
        displayIndex: Int,
        relativeRect: CGRect,
        zoneName: String,
        targetURL: URL? = nil
    ) {
        self.appName = appName
        self.bundleId = bundleId
        self.displayIndex = displayIndex
        self.relativeRect = relativeRect
        self.zoneName = zoneName
        self.targetURL = targetURL
    }
}

public struct RestoreSnapshot: Sendable {
    public let timestamp: Date
    public let windowFrames: [CGWindowID: CGRect]
}

public struct RestoreReportItem: Sendable {
    public let appName: String
    public let status: String // "Restored", "Needs you", "Skipped"
    public let detail: String
    public let targetFrame: CGRect
    public let actualFrame: CGRect?
    public let isReused: Bool
}

public struct RestoreReport: Sendable {
    public let duration: TimeInterval
    public let items: [RestoreReportItem]
    public let successCount: Int
    public let warningCount: Int
    public let skippedCount: Int
    public let snapshot: RestoreSnapshot
    public let passedExitGate: Bool
}

@MainActor
public final class RestoreEngine {
    public static let shared = RestoreEngine()
    
    private let displayManager = DisplayManager.shared
    private let windowManager = WindowManager.shared
    private let appLauncher = AppLauncher.shared
    
    public init() {}
    
    /// Executes a restore of specified target app zones
    public func executeRestore(targets: [TargetAppZone]) async -> RestoreReport {
        let startTime = Date()
        let displays = displayManager.getDisplays()
        
        guard !displays.isEmpty else {
            return RestoreReport(
                duration: 0,
                items: [],
                successCount: 0,
                warningCount: 0,
                skippedCount: 0,
                snapshot: RestoreSnapshot(timestamp: Date(), windowFrames: [:]),
                passedExitGate: false
            )
        }
        
        // 1. Take pre-restore snapshot of existing windows
        let initialWindows = windowManager.getVisibleWindows()
        var snapshotFrames: [CGWindowID: CGRect] = [:]
        for w in initialWindows {
            snapshotFrames[w.id] = w.frame
        }
        let snapshot = RestoreSnapshot(timestamp: Date(), windowFrames: snapshotFrames)
        
        var reportItems: [RestoreReportItem] = []
        var successCount = 0
        var warningCount = 0
        var skippedCount = 0
        
        // Count running windows per bundle ID before restore to detect duplicates
        let preCounts = Dictionary(grouping: initialWindows, by: { $0.bundleId ?? "" }).mapValues { $0.count }
        
        for target in targets {
            let targetDisplay = displays.indices.contains(target.displayIndex) ? displays[target.displayIndex] : displays[0]
            let targetFrame = displayManager.calculateZoneRect(on: targetDisplay, relativeRect: target.relativeRect)
            
            // Check if app is already running with visible windows
            let hasExistingWindow = initialWindows.contains(where: {
                ($0.bundleId?.caseInsensitiveCompare(target.bundleId) == .orderedSame ||
                 $0.appName.caseInsensitiveCompare(target.appName) == .orderedSame) &&
                $0.isStandardWindow
            })
            
            // Ensure app is running or launch it
            do {
                _ = try await appLauncher.launchOrActivate(
                    bundleId: target.bundleId,
                    appName: target.appName,
                    targetURL: target.targetURL,
                    hasExistingWindow: hasExistingWindow
                )
            } catch {
                reportItems.append(RestoreReportItem(
                    appName: target.appName,
                    status: "Skipped",
                    detail: "Could not launch: \(error.localizedDescription)",
                    targetFrame: targetFrame,
                    actualFrame: nil,
                    isReused: false
                ))
                skippedCount += 1
                continue
            }
            
            // Allow window server a brief moment to map the window
            var targetWindow: WindowModel?
            for _ in 0..<20 {
                let windows = windowManager.getVisibleWindows()
                if let match = windows.first(where: {
                    ($0.bundleId?.caseInsensitiveCompare(target.bundleId) == .orderedSame ||
                     $0.appName.caseInsensitiveCompare(target.appName) == .orderedSame) &&
                    $0.isStandardWindow
                }) {
                    targetWindow = match
                    break
                }
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            }
            
            guard let window = targetWindow, let axElement = window.axElement else {
                reportItems.append(RestoreReportItem(
                    appName: target.appName,
                    status: "Needs you",
                    detail: "App launched but no standard window was detected",
                    targetFrame: targetFrame,
                    actualFrame: nil,
                    isReused: hasExistingWindow
                ))
                warningCount += 1
                continue
            }
            
            // Move and resize the window
            let moveResult = windowManager.setWindowFrame(axElement, to: targetFrame)
            
            switch moveResult {
            case .success(let actualFrame):
                reportItems.append(RestoreReportItem(
                    appName: target.appName,
                    status: "Restored",
                    detail: hasExistingWindow ? "Reused existing window in \(target.zoneName)" : "Launched and placed in \(target.zoneName)",
                    targetFrame: targetFrame,
                    actualFrame: actualFrame,
                    isReused: hasExistingWindow
                ))
                successCount += 1
                
            case .partial(let actualFrame, let reason):
                reportItems.append(RestoreReportItem(
                    appName: target.appName,
                    status: "Restored",
                    detail: "Placed with constraints: \(reason)",
                    targetFrame: targetFrame,
                    actualFrame: actualFrame,
                    isReused: hasExistingWindow
                ))
                successCount += 1
                
            case .failed(let error):
                reportItems.append(RestoreReportItem(
                    appName: target.appName,
                    status: "Needs you",
                    detail: "Failed to set frame: \(error)",
                    targetFrame: targetFrame,
                    actualFrame: nil,
                    isReused: hasExistingWindow
                ))
                warningCount += 1
            }
        }
        
        // Check for duplicates: post window count must not exceed pre window count for running apps
        let postWindows = windowManager.getVisibleWindows()
        let postCounts = Dictionary(grouping: postWindows, by: { $0.bundleId ?? "" }).mapValues { $0.count }
        
        var noDuplicates = true
        for target in targets {
            let pre = preCounts[target.bundleId] ?? 0
            let post = postCounts[target.bundleId] ?? 0
            if pre > 0 && post > pre {
                noDuplicates = false
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let passed = (successCount >= targets.count) && noDuplicates
        
        return RestoreReport(
            duration: duration,
            items: reportItems,
            successCount: successCount,
            warningCount: warningCount,
            skippedCount: skippedCount,
            snapshot: snapshot,
            passedExitGate: passed
        )
    }
    
    /// Undoes a restore by moving windows back to their snapshotted positions
    public func undoRestore(snapshot: RestoreSnapshot) -> Int {
        let windows = windowManager.getVisibleWindows()
        var restoredCount = 0
        
        for w in windows {
            if let savedFrame = snapshot.windowFrames[w.id], let ax = w.axElement {
                _ = windowManager.setWindowFrame(ax, to: savedFrame)
                restoredCount += 1
            }
        }
        
        return restoredCount
    }
}
