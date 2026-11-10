import Foundation
import CoreGraphics

public enum SnapshotKind: String, Codable, CaseIterable, Sendable {
    case autoBeforeRestore = "auto"
    case manual = "manual"
}

public struct WindowSnapshotItem: Codable, Equatable, Sendable {
    public let windowId: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let bundleId: String?
    public let title: String
    public let frame: CGRect // AX coordinates
    
    public init(
        windowId: CGWindowID,
        pid: pid_t,
        appName: String,
        bundleId: String?,
        title: String,
        frame: CGRect
    ) {
        self.windowId = windowId
        self.pid = pid
        self.appName = appName
        self.bundleId = bundleId
        self.title = title
        self.frame = frame
    }
}

public struct Snapshot: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let timestamp: Date
    public let kind: SnapshotKind
    public var sourceProjectId: UUID?
    public var sourceProjectName: String?
    public let displaySignature: DisplaySignature
    public let windows: [WindowSnapshotItem]
    
    public init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        kind: SnapshotKind = .autoBeforeRestore,
        sourceProjectId: UUID? = nil,
        sourceProjectName: String? = nil,
        displaySignature: DisplaySignature,
        windows: [WindowSnapshotItem]
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.kind = kind
        self.sourceProjectId = sourceProjectId
        self.sourceProjectName = sourceProjectName
        self.displaySignature = displaySignature
        self.windows = windows
    }
    
    /// Snapshots are automatically retained for 30 days per PRD
    public var isExpired: Bool {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return timestamp < thirtyDaysAgo
    }
}
