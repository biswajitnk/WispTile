import Foundation
import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics

public struct WindowModel: Identifiable, Hashable, @unchecked Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let bundleId: String?
    public let title: String
    public let frame: CGRect // AX coordinates
    public let isMinimized: Bool
    public let isStandardWindow: Bool
    public let axElement: AXUIElement?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: WindowModel, rhs: WindowModel) -> Bool {
        lhs.id == rhs.id
    }
}

public enum WindowMoveResult: Sendable {
    case success(actualFrame: CGRect)
    case partial(actualFrame: CGRect, reason: String)
    case failed(error: String)
}

@MainActor
public final class WindowManager {
    public static let shared = WindowManager()
    
    public init() {}
    
    /// Checks whether the application has Accessibility permissions
    public func isAccessibilityGranted(promptIfNot: Bool = false) -> Bool {
        if promptIfNot {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options: NSDictionary = [key: true]
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }
    
    /// IDs of normal app windows on the current desktop (cheap: no Accessibility calls).
    public func onScreenWindowIDs(excludingBundle own: String? = Bundle.main.bundleIdentifier) -> Set<CGWindowID> {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let regular = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != own }
            .map(\.processIdentifier))
        return Set(list.compactMap { info -> CGWindowID? in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, regular.contains(pid),
                  let b = info[kCGWindowBounds as String] as? [String: Any],
                  let r = CGRect(dictionaryRepresentation: b as CFDictionary), r.width >= 50, r.height >= 50
            else { return nil }
            return info[kCGWindowNumber as String] as? CGWindowID
        })
    }
    
    /// Windows of regular apps that exist but aren't on the current desktop: other Spaces,
    /// full-screen Spaces, minimized or hidden. These can't be listed with positions here.
    public func countWindowsOffCurrentDesktop(excludingBundle own: String? = Bundle.main.bundleIdentifier) -> Int {
        func ids(_ opts: CGWindowListOption) -> Set<CGWindowID> {
            guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [] }
            let regular = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != own }
                .map { ($0.processIdentifier, true) })
            return Set(list.compactMap { info -> CGWindowID? in
                guard (info[kCGWindowLayer as String] as? Int) == 0,
                      let pid = info[kCGWindowOwnerPID as String] as? pid_t, regular[pid] == true,
                      let b = info[kCGWindowBounds as String] as? [String: Any],
                      let r = CGRect(dictionaryRepresentation: b as CFDictionary), r.width >= 50, r.height >= 50
                else { return nil }
                return info[kCGWindowNumber as String] as? CGWindowID
            })
        }
        let all = ids([.optionAll, .excludeDesktopElements])
        let here = ids([.optionOnScreenOnly, .excludeDesktopElements])
        return all.subtracting(here).count
    }
    
    /// Reads all standard visible windows belonging to regular applications
    public func getVisibleWindows() -> [WindowModel] {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        let regularApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let pidToApp = Dictionary(uniqueKeysWithValues: regularApps.map { ($0.processIdentifier, $0) })
        
        var results: [WindowModel] = []
        
        for info in windowInfoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let app = pidToApp[pid],
                  let windowId = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else {
                continue
            }
            
            // Exclude empty or offscreen windows
            if frame.width < 50 || frame.height < 50 {
                continue
            }
            
            let title = (info[kCGWindowName as String] as? String) ?? ""
            let appName = app.localizedName ?? (info[kCGWindowOwnerName as String] as? String) ?? "Unknown"
            let bundleId = app.bundleIdentifier
            
            // Inspect via AXUIElement
            let (axWindow, isStandard, isMinimized) = findAXWindow(pid: pid, targetFrame: frame, targetTitle: title)
            
            // Only include standard windows (not tooltips, menus, popups)
            if isStandard {
                results.append(WindowModel(
                    id: windowId,
                    pid: pid,
                    appName: appName,
                    bundleId: bundleId,
                    title: title,
                    frame: frame,
                    isMinimized: isMinimized,
                    isStandardWindow: isStandard,
                    axElement: axWindow
                ))
            }
        }
        
        return results
    }
    
    /// Finds the AXUIElement corresponding to a window
    private func findAXWindow(pid: pid_t, targetFrame: CGRect, targetTitle: String) -> (AXUIElement?, Bool, Bool) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return (nil, true, false)
        }
        
        for window in windows {
            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
            let subrole = subroleRef as? String
            
            // Standard windows only
            let isStandard = (subrole == (kAXStandardWindowSubrole as String) || subrole == nil)
            
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
            
            var point = CGPoint.zero
            var size = CGSize.zero
            if let posRef = posRef, AXValueGetType(posRef as! AXValue) == .cgPoint {
                AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
            }
            if let sizeRef = sizeRef, AXValueGetType(sizeRef as! AXValue) == .cgSize {
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            }
            
            var minRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRef)
            let isMinimized = (minRef as? Bool) ?? false
            
            // Match tolerance: within 10 points
            let posMatches = abs(point.x - targetFrame.origin.x) < 10 && abs(point.y - targetFrame.origin.y) < 10
            let sizeMatches = abs(size.width - targetFrame.size.width) < 10 && abs(size.height - targetFrame.size.height) < 10
            
            if posMatches && sizeMatches {
                return (window, isStandard, isMinimized)
            }
        }
        
        // Match by title
        if !targetTitle.isEmpty {
            for window in windows {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                if let title = titleRef as? String, title == targetTitle {
                    var subroleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
                    let subrole = subroleRef as? String
                    let isStandard = (subrole == (kAXStandardWindowSubrole as String) || subrole == nil)
                    return (window, isStandard, false)
                }
            }
        }
        
        return (windows.first, true, false)
    }
    
    /// Repositions and resizes a window to a target frame in AX coordinates
    public func setWindowFrame(_ element: AXUIElement, to targetFrame: CGRect) -> WindowMoveResult {
        guard isAccessibilityGranted() else {
            return .failed(error: "Accessibility permission not granted")
        }
        
        // Unminimize if minimized
        var isMinRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &isMinRef) == .success,
           let isMin = isMinRef as? Bool, isMin {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Step 1: Set position first
        var pos = targetFrame.origin
        guard let posVal = AXValueCreate(.cgPoint, &pos) else {
            return .failed(error: "Failed to create AXValue for position")
        }
        _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posVal)
        
        // Step 2: Set size
        var size = targetFrame.size
        guard let sizeVal = AXValueCreate(.cgSize, &size) else {
            return .failed(error: "Failed to create AXValue for size")
        }
        _ = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeVal)
        
        // Step 3: Re-apply position (handles cases where resizing shifted the window)
        _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posVal)
        
        // Step 4: Raise window
        _ = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        
        // Small settle delay for window server
        Thread.sleep(forTimeInterval: 0.05)
        
        // Read back actual frame
        let actual = getWindowFrame(element)
        guard let actualFrame = actual else {
            return .failed(error: "Could not read back window frame")
        }
        
        let dx = abs(actualFrame.origin.x - targetFrame.origin.x)
        let dy = abs(actualFrame.origin.y - targetFrame.origin.y)
        let dw = abs(actualFrame.size.width - targetFrame.size.width)
        let dh = abs(actualFrame.size.height - targetFrame.size.height)
        
        // Tolerances: 5 points for position, 25 points for size
        if dx <= 5 && dy <= 5 && dw <= 25 && dh <= 25 {
            return .success(actualFrame: actualFrame)
        } else {
            return .partial(
                actualFrame: actualFrame,
                reason: "Window constrained by app: target=\(targetFrame), actual=\(actualFrame)"
            )
        }
    }
    
    /// Reads the current frame of an AXUIElement
    public func getWindowFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        let posRes = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
        let sizeRes = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        guard posRes == .success, sizeRes == .success,
              let posVal = posRef, let sizeVal = sizeRef else {
            return nil
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else {
            return nil
        }
        
        return CGRect(origin: point, size: size)
    }
}
