import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Real window screenshots via ScreenCaptureKit (needs Screen Recording permission).
@MainActor
enum WindowShots {
    static var hasAccess: Bool { CGPreflightScreenCaptureAccess() }
    
    static func requestAccess() {
        if !CGRequestScreenCaptureAccess() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// Captures each window (by CGWindowID) at up to `maxWidth` px wide. Returns only the ones that succeeded.
    static func capture(windowIDs: [CGWindowID], maxWidth: CGFloat = 640) async -> [CGWindowID: NSImage] {
        guard hasAccess, #available(macOS 14.0, *), !windowIDs.isEmpty else { return [:] }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else { return [:] }
        var out: [CGWindowID: NSImage] = [:]
        for w in content.windows where windowIDs.contains(w.windowID) {
            let filter = SCContentFilter(desktopIndependentWindow: w)
            let cfg = SCStreamConfiguration()
            let scale = min(1, maxWidth / max(1, w.frame.width))
            cfg.width = max(1, Int(w.frame.width * scale))
            cfg.height = max(1, Int(w.frame.height * scale))
            cfg.showsCursor = false
            if let cg = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg) {
                out[w.windowID] = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }
        }
        return out
    }
    
    static func png(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
