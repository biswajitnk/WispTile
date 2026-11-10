import Foundation
import CoreGraphics

public struct DisplaySignature: Codable, Hashable, Equatable, Sendable, CustomStringConvertible {
    public let screenCount: Int
    public let resolutions: [CGSize]
    
    public init(screens: [DisplayInfo]) {
        self.screenCount = screens.count
        self.resolutions = screens.map { $0.cocoaFrame.size }
    }
    
    public init(screenCount: Int, resolutions: [CGSize]) {
        self.screenCount = screenCount
        self.resolutions = resolutions
    }
    
    public var description: String {
        let resStrings = resolutions.map { "\(Int($0.width))×\(Int($0.height))" }.joined(separator: " + ")
        return "\(screenCount) display\(screenCount == 1 ? "" : "s") (\(resStrings))"
    }
    
    public var rawValue: String {
        let resStrings = resolutions.map { "\(Int($0.width))x\(Int($0.height))" }.joined(separator: "+")
        return "\(screenCount)_\(resStrings)"
    }
}

public struct ProjectLayout: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var displaySignature: DisplaySignature
    public var templateId: UUID?
    /// Zones mapped per display index (0 = primary, 1 = external, etc.)
    public var displayZones: [Int: [Zone]]
    /// Mapping of zoneId to ProjectItem IDs assigned to that zone
    public var zoneAssignments: [String: [UUID]]
    
    public init(
        id: UUID = UUID(),
        displaySignature: DisplaySignature,
        templateId: UUID? = nil,
        displayZones: [Int: [Zone]] = [:],
        zoneAssignments: [String: [UUID]] = [:]
    ) {
        self.id = id
        self.displaySignature = displaySignature
        self.templateId = templateId
        self.displayZones = displayZones
        self.zoneAssignments = zoneAssignments
    }
}
