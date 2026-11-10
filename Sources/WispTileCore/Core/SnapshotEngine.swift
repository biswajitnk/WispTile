import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices

public struct UndoResult: Sendable {
    public let success: Bool
    public let revertedCount: Int
    public let totalCount: Int
    public let message: String
}

@MainActor
public final class SnapshotEngine {
    public static let shared = SnapshotEngine()
    
    private let windowManager = WindowManager.shared
    private let displayManager = DisplayManager.shared
    private let storageEngine = StorageEngine.shared
    
    public init() {}
    
    /// Creates a snapshot of all currently open standard windows
    @discardableResult
    public func createSnapshot(
        name: String? = nil,
        kind: SnapshotKind = .autoBeforeRestore,
        sourceProject: Project? = nil
    ) -> Snapshot {
        let windows = windowManager.getVisibleWindows()
        let displays = displayManager.getDisplays()
        let signature = DisplaySignature(screens: displays)
        
        let defaultName = name ?? (kind == .autoBeforeRestore
            ? "Auto-snapshot before restore"
            : "Manual snapshot (\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)))")
        
        let snapshotItems = windows.map { w in
            WindowSnapshotItem(
                windowId: w.id,
                pid: w.pid,
                appName: w.appName,
                bundleId: w.bundleId,
                title: w.title,
                frame: w.frame
            )
        }
        
        let snapshot = Snapshot(
            name: defaultName,
            timestamp: Date(),
            kind: kind,
            sourceProjectId: sourceProject?.id,
            sourceProjectName: sourceProject?.name,
            displaySignature: signature,
            windows: snapshotItems
        )
        
        try? storageEngine.saveSnapshot(snapshot)
        return snapshot
    }
    
    /// Reverts windows to the positions saved in a snapshot
    public func rollback(snapshot: Snapshot) -> UndoResult {
        let liveWindows = windowManager.getVisibleWindows()
        var reverted = 0
        var used = Set<CGWindowID>() // never move one live window for two saved ones
        
        // Exact window IDs first, then same app (title match preferred) for windows that were reopened.
        let exact = snapshot.windows.filter { s in liveWindows.contains(where: { $0.id == s.windowId }) }
        let rest = snapshot.windows.filter { s in !liveWindows.contains(where: { $0.id == s.windowId }) }
        for savedItem in exact + rest {
            let free = liveWindows.filter { !used.contains($0.id) }
            let liveMatch = free.first(where: { $0.id == savedItem.windowId }) ??
                            free.first(where: { $0.appName == savedItem.appName && $0.title == savedItem.title }) ??
                            free.first(where: { $0.appName == savedItem.appName && $0.bundleId == savedItem.bundleId })
            
            guard let window = liveMatch, let ax = window.axElement else { continue }
            used.insert(window.id)
            
            let res = windowManager.setWindowFrame(ax, to: savedItem.frame)
            switch res {
            case .success, .partial:
                reverted += 1
            case .failed:
                break
            }
        }
        
        return UndoResult(
            success: reverted > 0 || snapshot.windows.isEmpty,
            revertedCount: reverted,
            totalCount: snapshot.windows.count,
            message: "Restored \(reverted) of \(snapshot.windows.count) window positions"
        )
    }
    
    /// Reverts to the most recent automatic snapshot taken within the undo time limit (10 minutes)
    public func undoLastRestore(maxAgeSeconds: TimeInterval = 600) -> UndoResult {
        let snapshots = storageEngine.loadSnapshots()
        guard let latest = snapshots.first(where: { $0.kind == .autoBeforeRestore }) else {
            return UndoResult(success: false, revertedCount: 0, totalCount: 0, message: "No restore snapshot found")
        }
        
        let age = Date().timeIntervalSince(latest.timestamp)
        if age > maxAgeSeconds {
            return UndoResult(
                success: false,
                revertedCount: 0,
                totalCount: latest.windows.count,
                message: "Undo buffer expired (available for 10 minutes, snapshot is \(Int(age / 60)) minutes old)"
            )
        }
        
        return rollback(snapshot: latest)
    }
}
