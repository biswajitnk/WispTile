import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices

public enum TilingCommand: String, CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case center
    case topLeftQuadrant
    case topRightQuadrant
    case bottomLeftQuadrant
    case bottomRightQuadrant
    
    public var relativeRect: CGRect {
        switch self {
        case .leftHalf:
            return CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0)
        case .rightHalf:
            return CGRect(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        case .topHalf:
            return CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.5)
        case .bottomHalf:
            return CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.5)
        case .maximize:
            return CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        case .center:
            return CGRect(x: 0.125, y: 0.075, width: 0.75, height: 0.85)
        case .topLeftQuadrant:
            return CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5)
        case .topRightQuadrant:
            return CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5)
        case .bottomLeftQuadrant:
            return CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRightQuadrant:
            return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        }
    }
}

@MainActor
public final class TilingEngine {
    public static let shared = TilingEngine()
    
    private let displayManager = DisplayManager.shared
    private let windowManager = WindowManager.shared
    private let storageEngine = StorageEngine.shared
    private let diagnosticsEngine = DiagnosticsEngine.shared
    
    public init() {}
    
    /// Calculates the pixel frame in AX coordinates for a given relative zone on a display
    public func calculateZoneFrame(
        on display: DisplayInfo,
        relativeRect: CGRect,
        gap: CGFloat? = nil,
        padding: CGFloat? = nil
    ) -> CGRect {
        let settings = storageEngine.loadSettings()
        let effectiveGap = gap ?? settings.gapBetweenWindows
        let effectivePadding = padding ?? settings.screenEdgePadding
        
        return displayManager.calculateZoneRect(
            on: display,
            relativeRect: relativeRect,
            gap: effectiveGap,
            padding: effectivePadding
        )
    }
    
    /// Where a project item belongs on a display.
    /// Captured window positions (zones named `zone_N`, or custom rects) come back exactly as saved;
    /// template zones get the user's edge padding and gaps. Using padding on captured positions made
    /// every capture → restore cycle shrink windows and made untouched workspaces look drifted.
    public func restoreFrame(for item: ProjectItem, layout: ProjectLayout?, on display: DisplayInfo,
                             template: Template? = nil, index: Int = 0) -> (frame: CGRect, zoneName: String) {
        // A project arranged with a layout template: each app goes to its chosen zone, else by list order.
        if let template, let zone = Self.zone(for: item, index: index, in: template) {
            let builtIn = template.isBuiltIn || Template.builtInPresets.contains(where: { $0.id == template.id })
            let frame = calculateZoneFrame(on: display, relativeRect: zone.relativeRect,
                                           gap: builtIn ? nil : template.gap, padding: builtIn ? nil : template.padding)
            return (frame, zone.name)
        }
        if let zoneId = item.zoneId,
           let zone = layout?.displayZones[item.displayIndex]?.first(where: { $0.id == zoneId }) {
            let captured = zoneId.hasPrefix("zone_")
            let frame = calculateZoneFrame(on: display, relativeRect: zone.relativeRect,
                                           gap: captured ? 0 : nil, padding: captured ? 0 : nil)
            return (frame, zone.name)
        }
        if let custom = item.customRelativeRect {
            return (calculateZoneFrame(on: display, relativeRect: custom, gap: 0, padding: 0), "Custom Zone")
        }
        return (calculateZoneFrame(on: display, relativeRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)), "Default Zone")
    }
    
    /// The template zone for a project item: its chosen zone, or by position in the list (extras stack in the last zone).
    public static func zone(for item: ProjectItem, index: Int, in template: Template) -> Zone? {
        guard !template.zones.isEmpty else { return nil }
        if let id = item.templateZoneId, let z = template.zones.first(where: { $0.id == id }) { return z }
        return template.zones[min(max(0, index), template.zones.count - 1)]
    }
    
    /// Tiles a single window using a keyboard tiling command
    @discardableResult
    public func tileWindow(
        _ window: AXUIElement,
        command: TilingCommand,
        display: DisplayInfo? = nil
    ) -> WindowMoveResult {
        let targetDisplay = display ?? displayManager.primaryDisplay
        guard let currentDisplay = targetDisplay else {
            return .failed(error: "No active display found")
        }
        
        let targetFrame = calculateZoneFrame(on: currentDisplay, relativeRect: command.relativeRect)
        diagnosticsEngine.recordTilingOperation()
        return windowManager.setWindowFrame(window, to: targetFrame)
    }
    
    /// Tiles multiple windows using a specified template on a target display
    /// Which zone each window goes into. Apps with a chosen zone (by app name → zone id) go there;
    /// the rest fill the free zones left to right in their current on-screen order, so tiling keeps
    /// the arrangement you already have. Windows beyond the free zones stack in the last zone.
    /// The Layouts preview and Tile Now both use this, so what you see is what you get.
    public static func assignZones(apps: [String], minX: [CGFloat], template: Template, choices: [String: String]) -> [Int] {
        let count = template.zones.count
        guard count > 0 else { return apps.map { _ in 0 } }
        var result = Array(repeating: -1, count: apps.count)
        var taken = Set<Int>()
        for (i, app) in apps.enumerated() {
            if let id = choices[app], let z = template.zones.firstIndex(where: { $0.id == id }) {
                result[i] = z
                taken.insert(z)
            }
        }
        var free = (0..<count).filter { !taken.contains($0) }
        let unassigned = apps.indices.filter { result[$0] < 0 }.sorted { minX[$0] < minX[$1] }
        for i in unassigned {
            result[i] = free.isEmpty ? count - 1 : free.removeFirst()
        }
        return result
    }
    
    /// Apps whose windows stayed bigger than their zone in the last `tileWindows` call
    /// (they have a minimum size), so they overlap the gaps or their neighbours.
    public private(set) var lastTooLargeApps: [String] = []
    
    public func tileWindows(
        _ windows: [WindowModel],
        using template: Template,
        on display: DisplayInfo? = nil,
        zoneIndices: [Int]? = nil
    ) -> [WindowModel: WindowMoveResult] {
        let targetDisplay = display ?? displayManager.primaryDisplay
        guard let currentDisplay = targetDisplay, !template.zones.isEmpty else {
            return [:]
        }
        
        var results: [WindowModel: WindowMoveResult] = [:]
        lastTooLargeApps = []
        
        for (i, window) in windows.enumerated() {
            guard let ax = window.axElement else { continue }
            
            // Pick the assigned zone, else by index; stack in the last zone if more windows than zones
            let zoneIndex = min(zoneIndices.flatMap { $0.indices.contains(i) ? $0[i] : nil } ?? i, template.zones.count - 1)
            let zone = template.zones[zoneIndex]
            
            // Built-in presets follow the Snapping and Spacing settings; custom templates keep their own spacing.
            let builtIn = template.isBuiltIn || Template.builtInPresets.contains(where: { $0.id == template.id })
            let frame = calculateZoneFrame(
                on: currentDisplay,
                relativeRect: zone.relativeRect,
                gap: builtIn ? nil : template.gap,
                padding: builtIn ? nil : template.padding
            )
            
            var moveResult = windowManager.setWindowFrame(ax, to: frame)
            
            // Some apps refuse to get smaller than a minimum size. Note them, and pull the window
            // back on screen if its extra size pushed it past the edge.
            let actual: CGRect? = {
                switch moveResult {
                case .success(let f), .partial(let f, _): return f
                case .failed: return nil
                }
            }()
            if let actual, actual.width > frame.width + 2 || actual.height > frame.height + 2 {
                if !lastTooLargeApps.contains(window.appName) { lastTooLargeApps.append(window.appName) }
                let vis = currentDisplay.axVisibleFrame
                var onScreen = actual
                if onScreen.maxX > vis.maxX { onScreen.origin.x = max(vis.minX, vis.maxX - onScreen.width) }
                if onScreen.maxY > vis.maxY { onScreen.origin.y = max(vis.minY, vis.maxY - onScreen.height) }
                if onScreen.origin != actual.origin {
                    moveResult = windowManager.setWindowFrame(ax, to: onScreen)
                }
            }
            results[window] = moveResult
        }
        
        return results
    }
    
    /// Detects snap command when cursor or window is dragged near screen edges
    public func detectSnapCommand(
        mouseLocation: CGPoint,
        display: DisplayInfo,
        edgeThreshold: CGFloat = 30.0
    ) -> TilingCommand? {
        let vis = display.axVisibleFrame
        
        let isLeft = mouseLocation.x <= (vis.origin.x + edgeThreshold)
        let isRight = mouseLocation.x >= (vis.origin.x + vis.width - edgeThreshold)
        let isTop = mouseLocation.y <= (vis.origin.y + edgeThreshold)
        let isBottom = mouseLocation.y >= (vis.origin.y + vis.height - edgeThreshold)
        
        if isTop && isLeft { return .topLeftQuadrant }
        if isTop && isRight { return .topRightQuadrant }
        if isBottom && isLeft { return .bottomLeftQuadrant }
        if isBottom && isRight { return .bottomRightQuadrant }
        
        if isTop { return .maximize }
        if isLeft { return .leftHalf }
        if isRight { return .rightHalf }
        if isBottom { return .bottomHalf }
        
        return nil
    }
}
