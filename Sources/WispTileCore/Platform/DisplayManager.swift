import Foundation
import AppKit
import CoreGraphics

public struct DisplayInfo: Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    public let isPrimary: Bool
    public let isBuiltIn: Bool
    public let hasNotch: Bool
    public let safeAreaTopInset: CGFloat
    
    // Cocoa coordinates (origin: bottom-left of primary screen, Y upwards)
    public let cocoaFrame: CGRect
    public let cocoaVisibleFrame: CGRect
    
    // Accessibility / Quartz coordinates (origin: top-left of primary screen, Y downwards)
    public let axFrame: CGRect
    public let axVisibleFrame: CGRect
}

@MainActor
public final class DisplayManager {
    public static let shared = DisplayManager()
    
    private var displayReconfigCallback: CGDisplayReconfigurationCallBack?
    public var onDisplayReconfigured: (@Sendable (CGDirectDisplayID, CGDisplayChangeSummaryFlags) -> Void)?
    
    public init() {}
    
    /// Queries all connected screens and converts their coordinates to both Cocoa and Accessibility frames.
    public func getDisplays() -> [DisplayInfo] {
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first(where: { $0.frame.origin == .zero }) ?? screens.first else {
            return []
        }
        
        let primaryHeight = primaryScreen.frame.height
        
        return screens.enumerated().map { (index, screen) in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
            let isPrimary = (screen == primaryScreen)
            let isBuiltIn = CGDisplayIsBuiltin(screenNumber) != 0
            
            // Check for notch via safeAreaInsets
            let topInset = screen.safeAreaInsets.top
            let hasNotch = topInset > 0.0
            
            let cocoaFrame = screen.frame
            let cocoaVis = screen.visibleFrame
            
            // Conversion to AX coordinates:
            // AX Y = primaryHeight - (Cocoa Y + Cocoa Height)
            let axFrame = CGRect(
                x: cocoaFrame.origin.x,
                y: primaryHeight - (cocoaFrame.origin.y + cocoaFrame.height),
                width: cocoaFrame.width,
                height: cocoaFrame.height
            )
            
            let axVis = CGRect(
                x: cocoaVis.origin.x,
                y: primaryHeight - (cocoaVis.origin.y + cocoaVis.height),
                width: cocoaVis.width,
                height: cocoaVis.height
            )
            
            return DisplayInfo(
                id: screenNumber,
                name: screen.localizedName,
                isPrimary: isPrimary,
                isBuiltIn: isBuiltIn,
                hasNotch: hasNotch,
                safeAreaTopInset: topInset,
                cocoaFrame: cocoaFrame,
                cocoaVisibleFrame: cocoaVis,
                axFrame: axFrame,
                axVisibleFrame: axVis
            )
        }
    }
    
    /// Returns the primary display
    public var primaryDisplay: DisplayInfo? {
        getDisplays().first(where: { $0.isPrimary }) ?? getDisplays().first
    }
    
    /// Calculate a zone frame in Accessibility coordinates given percentage rects of the visible frame
    public func calculateZoneRect(
        on display: DisplayInfo,
        relativeRect: CGRect,
        gap: CGFloat = 8.0,
        padding: CGFloat = 12.0
    ) -> CGRect {
        let vis = display.axVisibleFrame
        
        let usableX = vis.origin.x + padding
        let usableY = vis.origin.y + padding
        let usableWidth = max(0, vis.width - (padding * 2))
        let usableHeight = max(0, vis.height - (padding * 2))
        
        let rawX = usableX + (relativeRect.origin.x * usableWidth)
        let rawY = usableY + (relativeRect.origin.y * usableHeight)
        let rawW = relativeRect.width * usableWidth
        let rawH = relativeRect.height * usableHeight
        
        let halfGap = gap / 2.0
        let isLeftEdge = relativeRect.origin.x <= 0.001
        let isRightEdge = (relativeRect.origin.x + relativeRect.width) >= 0.999
        let isTopEdge = relativeRect.origin.y <= 0.001
        let isBottomEdge = (relativeRect.origin.y + relativeRect.height) >= 0.999
        
        let finalX = isLeftEdge ? rawX : rawX + halfGap
        let finalY = isTopEdge ? rawY : rawY + halfGap
        let finalW = rawW - (isLeftEdge ? 0 : halfGap) - (isRightEdge ? 0 : halfGap)
        let finalH = rawH - (isTopEdge ? 0 : halfGap) - (isBottomEdge ? 0 : halfGap)
        
        return CGRect(
            x: round(finalX),
            y: round(finalY),
            width: round(max(100, finalW)),
            height: round(max(100, finalH))
        )
    }
    
    /// Starts monitoring display changes (plug/unplug, resolution changes, mirroring)
    public func startMonitoring(callback: @escaping @Sendable (CGDirectDisplayID, CGDisplayChangeSummaryFlags) -> Void) {
        self.onDisplayReconfigured = callback
        
        let reconfigCallback: CGDisplayReconfigurationCallBack = { display, flags, userInfo in
            guard let userInfo = userInfo else { return }
            let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.onDisplayReconfigured?(display, flags)
        }
        
        self.displayReconfigCallback = reconfigCallback
        let unmanaged = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(reconfigCallback, unmanaged)
    }
    
    /// Stops monitoring display changes
    public func stopMonitoring() {
        if let callback = displayReconfigCallback {
            let unmanaged = Unmanaged.passUnretained(self).toOpaque()
            CGDisplayRemoveReconfigurationCallback(callback, unmanaged)
            self.displayReconfigCallback = nil
            self.onDisplayReconfigured = nil
        }
    }
    
    deinit {
        // Can't invoke MainActor method in deinit, clean up callback directly
        if let callback = displayReconfigCallback {
            let unmanaged = Unmanaged.passUnretained(self).toOpaque()
            CGDisplayRemoveReconfigurationCallback(callback, unmanaged)
        }
    }
}
