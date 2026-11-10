import Foundation
import CoreGraphics

public enum LaunchBehavior: String, Codable, CaseIterable, Sendable {
    case reuseWindow = "reuse"
    case alwaysOpenNew = "always_new"
}

public enum SpacesMode: String, Codable, CaseIterable, Sendable {
    case currentSpace = "current"
    case originalSpaces = "original"
}

public enum FullscreenPolicy: String, Codable, CaseIterable, Sendable {
    case skipAndReport = "skip"
    case askEachTime = "ask"
}

public struct RestoreOptions: Codable, Equatable, Sendable {
    public var spacesMode: SpacesMode
    public var fullscreenPolicy: FullscreenPolicy
    public var reuseExistingWindows: Bool
    public var protectCallWindows: Bool
    public var askBeforeDisplayChanges: Bool
    
    public init(
        spacesMode: SpacesMode = .currentSpace,
        fullscreenPolicy: FullscreenPolicy = .skipAndReport,
        reuseExistingWindows: Bool = true,
        protectCallWindows: Bool = true,
        askBeforeDisplayChanges: Bool = true
    ) {
        self.spacesMode = spacesMode
        self.fullscreenPolicy = fullscreenPolicy
        self.reuseExistingWindows = reuseExistingWindows
        self.protectCallWindows = protectCallWindows
        self.askBeforeDisplayChanges = askBeforeDisplayChanges
    }
    
    public static let `default` = RestoreOptions()
}

public struct ProjectItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var appName: String
    public var bundleId: String
    /// File path, project directory, or browser URL associated with this item
    public var pathOrURL: String?
    public var displayIndex: Int
    public var zoneId: String?
    /// If not using a template zone, the custom relative frame (0.0 ... 1.0)
    public var customRelativeRect: CGRect?
    public var launchBehavior: LaunchBehavior
    /// Zone of the project's chosen layout template this app goes into (nil: by list order).
    public var templateZoneId: String? = nil
    
    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String,
        pathOrURL: String? = nil,
        displayIndex: Int = 0,
        zoneId: String? = nil,
        customRelativeRect: CGRect? = nil,
        launchBehavior: LaunchBehavior = .reuseWindow
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.pathOrURL = pathOrURL
        self.displayIndex = displayIndex
        self.zoneId = zoneId
        self.customRelativeRect = customRelativeRect
        self.launchBehavior = launchBehavior
    }
}

public struct Project: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var colorHex: String
    public var shortcut: String? // e.g. "⌥1"
    public var items: [ProjectItem]
    /// Layouts keyed by DisplaySignature rawValue
    public var layouts: [String: ProjectLayout]
    public var restoreOptions: RestoreOptions
    /// Layout template the project is arranged with on restore; nil restores windows as captured.
    public var layoutTemplateId: UUID? = nil
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4A2FC4",
        shortcut: String? = nil,
        items: [ProjectItem] = [],
        layouts: [String: ProjectLayout] = [:],
        restoreOptions: RestoreOptions = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shortcut = shortcut
        self.items = items
        self.layouts = layouts
        self.restoreOptions = restoreOptions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
