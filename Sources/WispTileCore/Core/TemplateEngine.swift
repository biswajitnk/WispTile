import Foundation
import CoreGraphics

public enum SplitOrientation: String, Codable, CaseIterable, Sendable {
    case horizontal // Splits into top and bottom
    case vertical   // Splits into left and right
}

public final class TemplateEngine: Sendable {
    public static let shared = TemplateEngine()
    
    public init() {}
    
    /// A built-in or saved template by id.
    public func template(id: UUID?) -> Template? {
        guard let id else { return nil }
        return Template.builtInPresets.first(where: { $0.id == id })
            ?? StorageEngine.shared.loadTemplates().first(where: { $0.id == id })
    }
    
    /// Snaps normalized coordinates (0.0 to 1.0) to a grid (default 12 cols x 8 rows as in Board 8)
    public func snapToGrid(rect: CGRect, cols: Int = 12, rows: Int = 8) -> CGRect {
        let colStep = 1.0 / CGFloat(cols)
        let rowStep = 1.0 / CGFloat(rows)
        
        let snappedX = round(rect.origin.x / colStep) * colStep
        let snappedY = round(rect.origin.y / rowStep) * rowStep
        
        // Ensure width and height are at least 1 grid cell
        let snappedW = max(colStep, round(rect.size.width / colStep) * colStep)
        let snappedH = max(rowStep, round(rect.size.height / rowStep) * rowStep)
        
        // Clamp inside [0, 1]
        let clampedX = min(max(0.0, snappedX), 1.0 - colStep)
        let clampedY = min(max(0.0, snappedY), 1.0 - rowStep)
        let clampedW = min(snappedW, 1.0 - clampedX)
        let clampedH = min(snappedH, 1.0 - clampedY)
        
        return CGRect(
            x: (clampedX * 1000).rounded() / 1000,
            y: (clampedY * 1000).rounded() / 1000,
            width: (clampedW * 1000).rounded() / 1000,
            height: (clampedH * 1000).rounded() / 1000
        )
    }
    
    /// Splits a zone into two zones horizontally or vertically
    public func splitZone(
        in template: Template,
        zoneId: String,
        orientation: SplitOrientation,
        ratio: CGFloat = 0.5
    ) -> Template {
        guard let index = template.zones.firstIndex(where: { $0.id == zoneId }) else {
            return template
        }
        
        let original = template.zones[index]
        var newZones = template.zones
        newZones.remove(at: index)
        
        let safeRatio = min(max(0.1, ratio), 0.9)
        let nextId = "\(template.zones.count + 1)"
        
        switch orientation {
        case .vertical:
            // Left and Right
            let z1 = Zone(
                id: original.id,
                name: "\(original.name) Left",
                relativeRect: CGRect(
                    x: original.relativeRect.origin.x,
                    y: original.relativeRect.origin.y,
                    width: original.relativeRect.width * safeRatio,
                    height: original.relativeRect.height
                ),
                defaultAppBundleId: original.defaultAppBundleId
            )
            let z2 = Zone(
                id: nextId,
                name: "\(original.name) Right",
                relativeRect: CGRect(
                    x: original.relativeRect.origin.x + (original.relativeRect.width * safeRatio),
                    y: original.relativeRect.origin.y,
                    width: original.relativeRect.width * (1.0 - safeRatio),
                    height: original.relativeRect.height
                )
            )
            newZones.insert(z1, at: index)
            newZones.insert(z2, at: index + 1)
            
        case .horizontal:
            // Top and Bottom
            let z1 = Zone(
                id: original.id,
                name: "\(original.name) Top",
                relativeRect: CGRect(
                    x: original.relativeRect.origin.x,
                    y: original.relativeRect.origin.y,
                    width: original.relativeRect.width,
                    height: original.relativeRect.height * safeRatio
                ),
                defaultAppBundleId: original.defaultAppBundleId
            )
            let z2 = Zone(
                id: nextId,
                name: "\(original.name) Bottom",
                relativeRect: CGRect(
                    x: original.relativeRect.origin.x,
                    y: original.relativeRect.origin.y + (original.relativeRect.height * safeRatio),
                    width: original.relativeRect.width,
                    height: original.relativeRect.height * (1.0 - safeRatio)
                )
            )
            newZones.insert(z1, at: index)
            newZones.insert(z2, at: index + 1)
        }
        
        var updated = template
        updated.zones = newZones
        return updated
    }
    
    /// Merges two zones by computing their bounding union
    public func mergeZones(
        in template: Template,
        zoneId1: String,
        zoneId2: String
    ) -> Template {
        guard let z1 = template.zones.first(where: { $0.id == zoneId1 }),
              let z2 = template.zones.first(where: { $0.id == zoneId2 }),
              z1.id != z2.id else {
            return template
        }
        
        let unionRect = z1.relativeRect.union(z2.relativeRect)
        let mergedZone = Zone(
            id: z1.id,
            name: "\(z1.name) + \(z2.name)",
            relativeRect: unionRect,
            defaultAppBundleId: z1.defaultAppBundleId ?? z2.defaultAppBundleId
        )
        
        var newZones = template.zones.filter { $0.id != zoneId1 && $0.id != zoneId2 }
        newZones.append(mergedZone)
        
        var updated = template
        updated.zones = newZones
        return updated
    }
}
