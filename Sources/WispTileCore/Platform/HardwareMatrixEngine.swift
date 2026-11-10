import Foundation
import CoreGraphics

/// Hardware Display Configuration Profile for automated matrix verification
public struct HardwareProfile: Sendable, Equatable, Identifiable {
    public enum DockPosition: String, Sendable, Codable {
        case bottom
        case left
        case right
        case hidden
    }
    
    public let id: String
    public let name: String
    public let pointSize: CGSize
    public let scaleFactor: CGFloat
    public let hasNotch: Bool
    public let safeAreaTopInset: CGFloat
    public let physicalNotchBounds: CGRect? // in points, relative to top-center of screen
    public let menuBarHeight: CGFloat
    public let dockPosition: DockPosition
    public let dockThickness: CGFloat
    
    public init(
        id: String,
        name: String,
        pointSize: CGSize,
        scaleFactor: CGFloat,
        hasNotch: Bool,
        safeAreaTopInset: CGFloat = 0.0,
        physicalNotchBounds: CGRect? = nil,
        menuBarHeight: CGFloat = 25.0,
        dockPosition: DockPosition = .bottom,
        dockThickness: CGFloat = 68.0
    ) {
        self.id = id
        self.name = name
        self.pointSize = pointSize
        self.scaleFactor = scaleFactor
        self.hasNotch = hasNotch
        self.safeAreaTopInset = safeAreaTopInset
        self.physicalNotchBounds = physicalNotchBounds
        self.menuBarHeight = menuBarHeight
        self.dockPosition = dockPosition
        self.dockThickness = dockThickness
    }
    
    /// Computes the usable AX visible frame (Quartz coordinate system: (0,0) at top-left, Y grows downward)
    public var axVisibleFrame: CGRect {
        var x: CGFloat = 0
        let y: CGFloat = hasNotch ? max(safeAreaTopInset, menuBarHeight) : menuBarHeight
        var width: CGFloat = pointSize.width
        var height: CGFloat = pointSize.height - y
        
        switch dockPosition {
        case .bottom:
            height -= dockThickness
        case .left:
            x += dockThickness
            width -= dockThickness
        case .right:
            width -= dockThickness
        case .hidden:
            break
        }
        
        return CGRect(x: x, y: y, width: max(0, width), height: max(0, height))
    }
    
    // MARK: - Built-in Hardware Profiles
    
    /// MacBook Pro 14-inch (M1/M2/M3/M4 Pro, Liquid Retina XDR with physical notch)
    public static let macBookPro14 = HardwareProfile(
        id: "mbp-14",
        name: "MacBook Pro 14\" (Notch)",
        pointSize: CGSize(width: 1512, height: 982),
        scaleFactor: 2.0,
        hasNotch: true,
        safeAreaTopInset: 32.0,
        physicalNotchBounds: CGRect(x: (1512 - 160) / 2, y: 0, width: 160, height: 32),
        menuBarHeight: 32.0,
        dockPosition: .bottom,
        dockThickness: 68.0
    )
    
    /// MacBook Pro 16-inch (M1/M2/M3/M4 Max, Liquid Retina XDR with physical notch)
    public static let macBookPro16 = HardwareProfile(
        id: "mbp-16",
        name: "MacBook Pro 16\" (Notch)",
        pointSize: CGSize(width: 1728, height: 1117),
        scaleFactor: 2.0,
        hasNotch: true,
        safeAreaTopInset: 32.0,
        physicalNotchBounds: CGRect(x: (1728 - 180) / 2, y: 0, width: 180, height: 32),
        menuBarHeight: 32.0,
        dockPosition: .bottom,
        dockThickness: 72.0
    )
    
    /// MacBook Air 13-inch (Non-notched / Classic M1)
    public static let macBookAir13 = HardwareProfile(
        id: "mba-13",
        name: "MacBook Air 13\" (Classic)",
        pointSize: CGSize(width: 1440, height: 900),
        scaleFactor: 2.0,
        hasNotch: false,
        safeAreaTopInset: 0.0,
        physicalNotchBounds: nil,
        menuBarHeight: 25.0,
        dockPosition: .bottom,
        dockThickness: 64.0
    )
    
    /// Apple Studio Display 27-inch 5K Retina
    public static let studioDisplay27 = HardwareProfile(
        id: "studio-27",
        name: "Apple Studio Display 27\" 5K",
        pointSize: CGSize(width: 2560, height: 1440),
        scaleFactor: 2.0,
        hasNotch: false,
        safeAreaTopInset: 0.0,
        physicalNotchBounds: nil,
        menuBarHeight: 25.0,
        dockPosition: .hidden, // Secondary display typically hides Dock
        dockThickness: 0.0
    )
    
    /// Apple Pro Display XDR 32-inch 6K Retina
    public static let proDisplayXDR32 = HardwareProfile(
        id: "pro-xdr-32",
        name: "Pro Display XDR 32\" 6K",
        pointSize: CGSize(width: 3008, height: 1692),
        scaleFactor: 2.0,
        hasNotch: false,
        safeAreaTopInset: 0.0,
        physicalNotchBounds: nil,
        menuBarHeight: 25.0,
        dockPosition: .hidden,
        dockThickness: 0.0
    )
    
    /// 34-inch Ultrawide 21:9 Display
    public static let ultrawide34 = HardwareProfile(
        id: "ultrawide-34",
        name: "Ultrawide 34\" 21:9 (3440×1440)",
        pointSize: CGSize(width: 3440, height: 1440),
        scaleFactor: 1.0,
        hasNotch: false,
        safeAreaTopInset: 0.0,
        physicalNotchBounds: nil,
        menuBarHeight: 25.0,
        dockPosition: .bottom,
        dockThickness: 60.0
    )
    
    /// 49-inch Super Ultrawide 32:9 Display
    public static let superUltrawide49 = HardwareProfile(
        id: "super-ultrawide-49",
        name: "Super Ultrawide 49\" 32:9 (5120×1440)",
        pointSize: CGSize(width: 5120, height: 1440),
        scaleFactor: 1.0,
        hasNotch: false,
        safeAreaTopInset: 0.0,
        physicalNotchBounds: nil,
        menuBarHeight: 25.0,
        dockPosition: .bottom,
        dockThickness: 60.0
    )
    
    /// Comprehensive test matrix of Mac hardware
    public static let allTestProfiles: [HardwareProfile] = [
        .macBookPro14,
        .macBookPro16,
        .macBookAir13,
        .studioDisplay27,
        .proDisplayXDR32,
        .ultrawide34,
        .superUltrawide49
    ]
}

/// Validation result for window placement on target hardware
public struct WindowPlacementValidation: Sendable, Equatable {
    public let isValid: Bool
    public let violations: [String]
    public let clampedFrame: CGRect
    
    public init(isValid: Bool, violations: [String], clampedFrame: CGRect) {
        self.isValid = isValid
        self.violations = violations
        self.clampedFrame = clampedFrame
    }
}

/// Engine to audit and enforce visible bounds and notch safety across the hardware matrix
public final class HardwareMatrixEngine: @unchecked Sendable {
    public static let shared = HardwareMatrixEngine()
    
    public init() {}
    
    /// Calculates tiled window frame in AX coordinates for a given relative zone on a profile
    public func calculateTiledRect(
        on profile: HardwareProfile,
        relativeRect: CGRect,
        gap: CGFloat = 8.0,
        padding: CGFloat = 12.0
    ) -> CGRect {
        let vis = profile.axVisibleFrame
        
        let usableX = vis.origin.x + padding
        let usableY = vis.origin.y + padding
        let usableWidth = max(0, vis.width - (padding * 2))
        let usableHeight = max(0, vis.height - (padding * 2))
        
        let rawX = usableX + (relativeRect.origin.x * usableWidth)
        let rawY = usableY + (relativeRect.origin.y * usableHeight)
        let rawW = relativeRect.width * usableWidth
        let rawH = relativeRect.height * usableHeight
        
        let isLeftEdge = relativeRect.origin.x <= 0.001
        let isRightEdge = (relativeRect.origin.x + relativeRect.width) >= 0.999
        let isTopEdge = relativeRect.origin.y <= 0.001
        let isBottomEdge = (relativeRect.origin.y + relativeRect.height) >= 0.999
        
        let halfGap = gap / 2.0
        let insetLeft = isLeftEdge ? 0 : halfGap
        let insetRight = isRightEdge ? 0 : halfGap
        let insetTop = isTopEdge ? 0 : halfGap
        let insetBottom = isBottomEdge ? 0 : halfGap
        
        let finalX = rawX + insetLeft
        let finalY = rawY + insetTop
        let finalW = max(50, rawW - insetLeft - insetRight)
        let finalH = max(50, rawH - insetTop - insetBottom)
        
        return CGRect(
            x: round(finalX),
            y: round(finalY),
            width: round(finalW),
            height: round(finalH)
        )
    }
    
    /// Validates whether a window placement violates notch boundaries, menu bar, or visible limits
    public func validateWindowPlacement(
        windowFrame: CGRect,
        on profile: HardwareProfile
    ) -> WindowPlacementValidation {
        var violations: [String] = []
        let vis = profile.axVisibleFrame
        
        // 1. Check Notch violation (must not intersect physical notch)
        if let notch = profile.physicalNotchBounds {
            if windowFrame.intersects(notch) {
                violations.append("Window intersects physical notch cutout [\(notch)]")
            }
        }
        
        // 2. Check Top Safe Area / Menu Bar boundary
        let topLimit = profile.hasNotch ? max(profile.safeAreaTopInset, profile.menuBarHeight) : profile.menuBarHeight
        if windowFrame.origin.y < topLimit {
            violations.append("Window origin Y (\(windowFrame.origin.y)) intrudes into menu bar / safe area top (\(topLimit))")
        }
        
        // 3. Check Left boundary
        if windowFrame.origin.x < vis.origin.x {
            violations.append("Window origin X (\(windowFrame.origin.x)) extends beyond left visible edge (\(vis.origin.x))")
        }
        
        // 4. Check Right boundary
        let rightEdge = windowFrame.origin.x + windowFrame.width
        let visibleRight = vis.origin.x + vis.width
        if rightEdge > visibleRight + 1.0 { // Allow 1pt rounding tolerance
            violations.append("Window right edge (\(rightEdge)) exceeds display visible right edge (\(visibleRight))")
        }
        
        // 5. Check Bottom boundary (Dock protection)
        let bottomEdge = windowFrame.origin.y + windowFrame.height
        let visibleBottom = vis.origin.y + vis.height
        if bottomEdge > visibleBottom + 1.0 {
            violations.append("Window bottom edge (\(bottomEdge)) overlaps Dock / visible bottom edge (\(visibleBottom))")
        }
        
        // Generate clamped safe frame
        let clampedX = max(vis.origin.x, min(windowFrame.origin.x, visibleRight - min(windowFrame.width, vis.width)))
        let clampedY = max(topLimit, min(windowFrame.origin.y, visibleBottom - min(windowFrame.height, vis.height)))
        let clampedW = min(windowFrame.width, vis.width)
        let clampedH = min(windowFrame.height, vis.height)
        let clampedFrame = CGRect(x: round(clampedX), y: round(clampedY), width: round(clampedW), height: round(clampedH))
        
        return WindowPlacementValidation(
            isValid: violations.isEmpty,
            violations: violations,
            clampedFrame: clampedFrame
        )
    }
    
    /// Audits all built-in profiles and standard templates, ensuring zero notch intrusions and zero visible frame bounds overflow
    public func auditHardwareMatrix() -> (passed: Bool, reports: [String]) {
        var allPassed = true
        var reports: [String] = []
        
        let templates = Template.builtInPresets
        
        for profile in HardwareProfile.allTestProfiles {
            var profileViolations = 0
            for template in templates {
                for zone in template.zones {
                    let rect = calculateTiledRect(on: profile, relativeRect: zone.relativeRect)
                    let result = validateWindowPlacement(windowFrame: rect, on: profile)
                    if !result.isValid {
                        allPassed = false
                        profileViolations += result.violations.count
                        reports.append("❌ [\(profile.name)] Template '\(template.name)' Zone \(zone.id): \(result.violations.joined(separator: ", "))")
                    }
                }
            }
            if profileViolations == 0 {
                reports.append("✅ [\(profile.name)] Verified safe visible bounds, notch clearance, and Dock padding across all templates.")
            }
        }
        
        return (allPassed, reports)
    }
}
