import Foundation
import AppKit
import CoreGraphics
@preconcurrency import ApplicationServices
import Carbon

@MainActor
@main
struct WispTileSpike {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        let command = args.first ?? "help"
        
        switch command {
        case "status":
            runStatus()
            
        case "displays":
            runDisplays()
            
        case "windows":
            runWindows()
            
        case "monitor-displays":
            runMonitorDisplays()
            
        case "test-hotkey":
            runTestHotkey()
            
        case "test-move":
            let subArgs = Array(args.dropFirst())
            if subArgs.count >= 5,
               let x = Double(subArgs[1]),
               let y = Double(subArgs[2]),
               let w = Double(subArgs[3]),
               let h = Double(subArgs[4]) {
                runTestMove(appName: subArgs[0], targetRect: CGRect(x: x, y: y, width: w, height: h))
            } else {
                print("Usage: wisptile-spike test-move <appName> <x> <y> <w> <h>")
            }
            
        case "run-gate":
            await runExitGate()
            
        case "request-permission":
            let granted = WindowManager.shared.isAccessibilityGranted(promptIfNot: true)
            print("Accessibility permission prompt shown. Granted: \(granted)")
            
        default:
            printUsage()
        }
    }
    
    static func printUsage() {
        print("""
        ========================================================================
        WispTile Phase 0 Spike CLI Harness
        ========================================================================
        Commands:
          status              Check Accessibility permissions, screens, and running apps
          request-permission  Prompt macOS Accessibility permission dialog
          displays            Inspect displays, resolutions, visible frames, and notch
          windows             List visible standard windows with frames and PIDs
          monitor-displays    Live monitor for display plug/unplug/reconfiguration events
          test-hotkey         Register global hotkey (⌥Space) and test callback
          test-move <app> <x> <y> <w> <h>  Test moving a specific app's window
          run-gate            Execute the Phase 0 Exit Gate:
                              Restore 3 apps across zones/displays without duplicates
        ========================================================================
        """)
    }
    
    static func runStatus() {
        print("\n--- [1] Checking macOS Accessibility Status ---")
        let isTrusted = WindowManager.shared.isAccessibilityGranted()
        print("Accessibility Granted (AXIsProcessTrusted): \(isTrusted ? "✅ YES" : "❌ NO")")
        if !isTrusted {
            print("👉 Run `wisptile-spike request-permission` or open:")
            print("   System Settings > Privacy & Security > Accessibility and enable your Terminal / Runner.")
        }
        
        print("\n--- [2] Checking Connected Displays ---")
        let displays = DisplayManager.shared.getDisplays()
        print("Connected display count: \(displays.count)")
        for (i, d) in displays.enumerated() {
            print("  [\(i)] \(d.name) (ID: \(d.id)) | Primary: \(d.isPrimary) | Built-In: \(d.isBuiltIn) | Notch: \(d.hasNotch ? "YES (\(d.safeAreaTopInset)pt)" : "NO")")
            print("      AX Usable Bounds: \(d.axVisibleFrame)")
        }
        
        print("\n--- [3] Checking Regular Running Applications ---")
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        print("Regular running apps count: \(regular.count)")
        for app in regular {
            print("  • \(app.localizedName ?? "Unknown") [\(app.bundleIdentifier ?? "no-bundle")] (PID: \(app.processIdentifier))")
        }
    }
    
    static func runDisplays() {
        print("\n================== Display Configuration & Coordinate Mapping ==================")
        let displays = DisplayManager.shared.getDisplays()
        for (i, d) in displays.enumerated() {
            print("Display #\(i): \(d.name)")
            print("  • Display ID: \(d.id)")
            print("  • Role: \(d.isPrimary ? "Primary Display" : "Secondary Display")")
            print("  • Hardware Type: \(d.isBuiltIn ? "Built-In Mac Display" : "External Display")")
            print("  • Notch Detected: \(d.hasNotch ? "YES (Safe area top inset: \(d.safeAreaTopInset) pt)" : "NO")")
            print("  • Cocoa Frame: origin=(\(d.cocoaFrame.origin.x), \(d.cocoaFrame.origin.y)), size=\(d.cocoaFrame.size.width)x\(d.cocoaFrame.size.height)")
            print("  • Cocoa Visible Frame (Dock/Menu bar excluded): origin=(\(d.cocoaVisibleFrame.origin.x), \(d.cocoaVisibleFrame.origin.y)), size=\(d.cocoaVisibleFrame.size.width)x\(d.cocoaVisibleFrame.size.height)")
            print("  • Accessibility / Quartz Frame: origin=(\(d.axFrame.origin.x), \(d.axFrame.origin.y)), size=\(d.axFrame.size.width)x\(d.axFrame.size.height)")
            print("  • Accessibility Usable Frame: origin=(\(d.axVisibleFrame.origin.x), \(d.axVisibleFrame.origin.y)), size=\(d.axVisibleFrame.size.width)x\(d.axVisibleFrame.size.height)")
            
            // Sample test zones
            let leftHalf = DisplayManager.shared.calculateZoneRect(on: d, relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0))
            let rightTop = DisplayManager.shared.calculateZoneRect(on: d, relativeRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
            let rightBottom = DisplayManager.shared.calculateZoneRect(on: d, relativeRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
            print("  • Calculated Zones (8pt gap, 12pt padding):")
            print("      - Left 50%: \(leftHalf)")
            print("      - Top Right 25%: \(rightTop)")
            print("      - Bottom Right 25%: \(rightBottom)")
            print("--------------------------------------------------------------------------------")
        }
    }
    
    static func runWindows() {
        print("\n================== Visible Standard Windows ==================")
        let windows = WindowManager.shared.getVisibleWindows()
        if windows.isEmpty {
            print("No regular on-screen windows detected.")
            return
        }
        
        for (i, w) in windows.enumerated() {
            print("[\(i+1)] \(w.appName) (PID: \(w.pid))")
            print("     Title: \"\(w.title)\"")
            print("     Bundle: \(w.bundleId ?? "none")")
            print("     Frame (AX): origin=(\(w.frame.origin.x), \(w.frame.origin.y)), size=\(w.frame.size.width)x\(w.frame.size.height)")
            print("     AXElement Attached: \(w.axElement != nil ? "YES" : "NO")")
        }
    }
    
    static func runMonitorDisplays() {
        print("\nListening for display changes (connect, disconnect, resolution change, mirror)...")
        print("Press Ctrl+C to stop.")
        
        DisplayManager.shared.startMonitoring { displayId, flags in
            let date = ISO8601DateFormatter().string(from: Date())
            print("[\(date)] 🖥 Display Event for Display ID \(displayId):")
            if flags.contains(.addFlag) { print("  + Display Added") }
            if flags.contains(.removeFlag) { print("  - Display Removed") }
            if flags.contains(.movedFlag) { print("  ~ Display Moved / Position Changed") }
            if flags.contains(.setMainFlag) { print("  ★ Primary Display Changed") }
            if flags.contains(.setModeFlag) { print("  ⚙ Resolution / Mode Changed") }
            if flags.contains(.enabledFlag) { print("  ✓ Display Enabled") }
            if flags.contains(.disabledFlag) { print("  ✗ Display Disabled") }
            if flags.contains(.mirrorFlag) { print("  ⇄ Mirroring Changed") }
        }
        
        RunLoop.current.run()
    }
    
    static func runTestHotkey() {
        print("\nRegistering global hotkey: ⌥Space (Option + Space)...")
        let hotKey = HotKey(id: 1, keyCode: 49, modifiers: UInt32(optionKey), name: "Option+Space Quick Switcher")
        
        let success = HotKeyManager.shared.register(hotKey: hotKey) {
            print("🔥 Global Hotkey Pressed: Option + Space! (WispTile Triggered)")
        }
        
        if success {
            print("✅ Hotkey registered successfully!")
            print("Switch to any other application and press Option+Space.")
            print("Running event loop for 10 seconds...")
            RunLoop.current.run(until: Date().addingTimeInterval(10.0))
            print("Done testing hotkey.")
        } else {
            print("❌ Failed to register hotkey.")
        }
    }
    
    static func runTestMove(appName: String, targetRect: CGRect) {
        print("Testing move for app '\(appName)' to \(targetRect)...")
        let windows = WindowManager.shared.getVisibleWindows()
        guard let match = windows.first(where: { $0.appName.caseInsensitiveCompare(appName) == .orderedSame }),
              let ax = match.axElement else {
            print("Window for '\(appName)' not found or no accessibility access.")
            return
        }
        
        let res = WindowManager.shared.setWindowFrame(ax, to: targetRect)
        switch res {
        case .success(let actual):
            print("✅ Successfully moved to: \(actual)")
        case .partial(let actual, let reason):
            print("⚠️ Partially moved to \(actual): \(reason)")
        case .failed(let err):
            print("❌ Move failed: \(err)")
        }
    }
    
    static func runExitGate() async {
        print("\n========================================================================")
        print("Executing Phase 0 Exit Gate Verification")
        print("Requirement: Restore 3 apps across zones/displays without duplicates")
        print("========================================================================")
        
        let isTrusted = WindowManager.shared.isAccessibilityGranted()
        guard isTrusted else {
            print("\n❌ Exit Gate Blocked: Accessibility permission is NOT granted.")
            print("Run `wisptile-spike request-permission` to grant permission in System Settings.")
            return
        }
        
        let displays = DisplayManager.shared.getDisplays()
        print("Detected \(displays.count) display(s).")
        
        let hasMultipleDisplays = displays.count > 1
        
        // Prepare test document for TextEdit
        let docURL = URL(fileURLWithPath: "/tmp/wisptile_spike_doc.txt")
        try? "WispTile Phase 0 Spike Document".write(to: docURL, atomically: true, encoding: .utf8)
        
        // Prepare folder URL for Finder
        let projectFolderURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        let targets = [
            TargetAppZone(
                appName: "TextEdit",
                bundleId: "com.apple.TextEdit",
                displayIndex: 0,
                relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
                zoneName: "Zone 1 · Left 50% (Editor)",
                targetURL: docURL
            ),
            TargetAppZone(
                appName: "Calculator",
                bundleId: "com.apple.calculator",
                displayIndex: hasMultipleDisplays ? 1 : 0,
                relativeRect: hasMultipleDisplays ? CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0) : CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5),
                zoneName: hasMultipleDisplays ? "Display 2 · Left 50%" : "Zone 2 · Top Right 25%"
            ),
            TargetAppZone(
                appName: "Finder",
                bundleId: "com.apple.finder",
                displayIndex: hasMultipleDisplays ? 1 : 0,
                relativeRect: hasMultipleDisplays ? CGRect(x: 0.5, y: 0.0, width: 0.5, height: 1.0) : CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
                zoneName: hasMultipleDisplays ? "Display 2 · Right 50%" : "Zone 3 · Bottom Right 25%",
                targetURL: projectFolderURL
            )
        ]
        
        print("\nTarget Layout:")
        for t in targets {
            print("  • \(t.appName) [\(t.bundleId)] -> Display #\(t.displayIndex) (\(t.zoneName))")
        }
        
        print("\nExecuting Restore Engine...")
        let report = await RestoreEngine.shared.executeRestore(targets: targets)
        
        print("\n------------------------- Restore Report -------------------------")
        print("Completed in: \(String(format: "%.2f", report.duration)) seconds")
        print("Summary: \(report.successCount) Restored · \(report.warningCount) Need You · \(report.skippedCount) Skipped")
        
        for item in report.items {
            let statusIcon = item.status == "Restored" ? "✅" : (item.status == "Needs you" ? "⚠️" : "⏭")
            print("  \(statusIcon) \(item.appName): \(item.status)")
            print("     Detail: \(item.detail)")
            print("     Reused Window: \(item.isReused ? "YES (no duplicate opened)" : "NO (new window)")")
            print("     Target Frame: \(item.targetFrame)")
            if let actual = item.actualFrame {
                print("     Actual Frame: \(actual)")
            }
        }
        
        print("\n------------------------- Exit Gate Result -------------------------")
        if report.passedExitGate {
            print("🎉 PHASE 0 EXIT GATE PASSED!")
            print("   3 apps successfully placed across designated zones/displays without duplicates.")
        } else {
            print("⚠️ Phase 0 Exit Gate did not fully pass yet. Review warnings/constraints above.")
        }
        
        print("\nTesting Snapshot Undo (Restoring previous window frames)...")
        let revertedCount = RestoreEngine.shared.undoRestore(snapshot: report.snapshot)
        print("✅ Undo completed: \(revertedCount) windows repositioned to pre-restore snapshot.")
    }
}
