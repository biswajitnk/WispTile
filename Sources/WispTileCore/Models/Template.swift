import Foundation
import CoreGraphics

public struct Zone: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    /// Normalized coordinates between 0.0 and 1.0 relative to display's usable visible area
    public var relativeRect: CGRect
    public var defaultAppBundleId: String?
    public var stackExtraWindows: Bool
    
    public init(
        id: String,
        name: String,
        relativeRect: CGRect,
        defaultAppBundleId: String? = nil,
        stackExtraWindows: Bool = true
    ) {
        self.id = id
        self.name = name
        self.relativeRect = relativeRect
        self.defaultAppBundleId = defaultAppBundleId
        self.stackExtraWindows = stackExtraWindows
    }
}

public struct Template: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var zones: [Zone]
    public var gap: CGFloat
    public var padding: CGFloat
    public var isBuiltIn: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        zones: [Zone],
        gap: CGFloat = 8.0,
        padding: CGFloat = 12.0,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.zones = zones
        self.gap = gap
        self.padding = padding
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Built-in Preset Templates (as designed in Boards 7 & 8)
public extension Template {
    /// Halves (Left 50%, Right 50%)
    static let halves = Template(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Halves",
        zones: [
            Zone(id: "1", name: "Left Half", relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0)),
            Zone(id: "2", name: "Right Half", relativeRect: CGRect(x: 0.5, y: 0.0, width: 0.5, height: 1.0))
        ],
        isBuiltIn: true
    )
    
    /// Thirds (Left 33%, Center 34%, Right 33%)
    static let thirds = Template(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Thirds",
        zones: [
            Zone(id: "1", name: "Left Column", relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.333, height: 1.0)),
            Zone(id: "2", name: "Center Column", relativeRect: CGRect(x: 0.333, y: 0.0, width: 0.334, height: 1.0)),
            Zone(id: "3", name: "Right Column", relativeRect: CGRect(x: 0.667, y: 0.0, width: 0.333, height: 1.0))
        ],
        isBuiltIn: true
    )
    
    /// Main + Stack (Main Editor Left 60%, Browser Top Right 40% x 50%, Terminal Bottom Right 40% x 50%)
    static let mainAndStack = Template(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Main + Stack",
        zones: [
            Zone(id: "1", name: "Editor", relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.6, height: 1.0)),
            Zone(id: "2", name: "Browser", relativeRect: CGRect(x: 0.6, y: 0.0, width: 0.4, height: 0.5)),
            Zone(id: "3", name: "Terminal", relativeRect: CGRect(x: 0.6, y: 0.5, width: 0.4, height: 0.5))
        ],
        isBuiltIn: true
    )
    
    /// Grid 2 × 2 (4 Quadrants)
    static let grid2x2 = Template(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Grid 2 × 2",
        zones: [
            Zone(id: "1", name: "Top Left", relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5)),
            Zone(id: "2", name: "Top Right", relativeRect: CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5)),
            Zone(id: "3", name: "Bottom Left", relativeRect: CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.5)),
            Zone(id: "4", name: "Bottom Right", relativeRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        ],
        isBuiltIn: true
    )
    
    /// Focus (Centered window with comfortable margin)
    static let focus = Template(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Focus",
        zones: [
            Zone(id: "1", name: "Center Focus", relativeRect: CGRect(x: 0.125, y: 0.075, width: 0.75, height: 0.85))
        ],
        isBuiltIn: true
    )
    
    /// All built-in presets
    static let builtInPresets: [Template] = [
        .mainAndStack,
        .halves,
        .thirds,
        .grid2x2,
        .focus
    ]
}
