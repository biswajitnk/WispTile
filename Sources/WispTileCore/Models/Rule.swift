import Foundation

public enum TriggerType: Codable, Equatable, Sendable {
    case externalDisplayConnect
    case externalDisplayDisconnect
    case folderOpen(path: String)
    case callStart
}

public enum ActionType: Codable, Equatable, Sendable {
    case suggestLayout(name: String)
    case applyLayout(name: String)
    case suggestProject(projectId: UUID)
    case pauseTiling(durationSeconds: TimeInterval)
}

public struct Rule: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var trigger: TriggerType
    public var action: ActionType
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        trigger: TriggerType,
        action: ActionType,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
    }
}

public struct ExcludedApps: Codable, Equatable, Sendable {
    public var bundleIds: Set<String>
    public var appNames: Set<String>
    
    public init(bundleIds: Set<String> = [], appNames: Set<String> = []) {
        self.bundleIds = bundleIds
        self.appNames = appNames
    }
    
    /// Default safety excluded apps (never tile call windows, system utility sheets, or preference panes)
    public static let defaults = ExcludedApps(
        bundleIds: [
            "us.zoom.xos",
            "com.apple.FaceTime",
            "com.apple.systempreferences",
            "com.apple.SystemSettings",
            "com.apple.calculator"
        ],
        appNames: [
            "Zoom",
            "FaceTime",
            "Google Meet",
            "System Settings",
            "System Preferences",
            "Calculator"
        ]
    )
    
    public func isExcluded(bundleId: String?, appName: String) -> Bool {
        if let bundleId = bundleId, bundleIds.contains(bundleId) {
            return true
        }
        return appNames.contains(appName)
    }
}
