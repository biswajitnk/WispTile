import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices

public struct AdaptationResult: Sendable {
    public let wasAdapted: Bool
    public let previousSignature: DisplaySignature
    public let newSignature: DisplaySignature
    public let windowsMovedCount: Int
    public let appliedLayoutName: String
}

@MainActor
public final class DisplayAdaptationEngine {
    public static let shared = DisplayAdaptationEngine()
    
    private let displayManager = DisplayManager.shared
    private let windowManager = WindowManager.shared
    private let tilingEngine = TilingEngine.shared
    private let rulesEngine = RulesEngine.shared
    
    private var lastKnownDisplayCount: Int = 1
    public var onAdaptationSuggested: ((_ project: Project, _ decision: DisplayAdaptDecision) -> Void)?
    
    public init() {
        self.lastKnownDisplayCount = displayManager.getDisplays().count
    }
    
    /// Starts monitoring for hardware display plug/unplug events
    public func startMonitoring(for activeProjectProvider: @escaping () -> Project?) {
        displayManager.startMonitoring { [weak self] displayId, flags in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let currentDisplays = self.displayManager.getDisplays()
                let currentCount = currentDisplays.count
                
                guard let project = activeProjectProvider() else {
                    self.lastKnownDisplayCount = currentCount
                    return
                }
                
                if currentCount < self.lastKnownDisplayCount {
                    // Display Disconnected!
                    let decision = self.rulesEngine.evaluateDisplayDisconnect(for: project, remainingDisplays: currentDisplays)
                    switch decision {
                    case .applyAutomatically(let layout):
                        _ = self.applyLayout(layout, displays: currentDisplays, for: project)
                    case .askUser:
                        self.onAdaptationSuggested?(project, decision)
                    case .doNothing:
                        break
                    }
                } else if currentCount > self.lastKnownDisplayCount {
                    // Display Connected!
                    let decision = self.rulesEngine.evaluateDisplayConnect(for: project, newDisplays: currentDisplays)
                    switch decision {
                    case .applyAutomatically(let layout):
                        _ = self.applyLayout(layout, displays: currentDisplays, for: project)
                    case .askUser:
                        self.onAdaptationSuggested?(project, decision)
                    case .doNothing:
                        break
                    }
                }
                
                self.lastKnownDisplayCount = currentCount
            }
        }
    }
    
    /// Applies a specific layout to current windows across given displays
    public func applyLayout(
        _ layout: ProjectLayout,
        displays: [DisplayInfo],
        for project: Project
    ) -> AdaptationResult {
        let liveWindows = windowManager.getVisibleWindows()
        var movedCount = 0
        
        let targetDisplay = displays.first ?? DisplayInfo(
            id: 1, name: "Screen", isPrimary: true, isBuiltIn: true, hasNotch: false, safeAreaTopInset: 0,
            cocoaFrame: .zero, cocoaVisibleFrame: .zero, axFrame: .zero, axVisibleFrame: .zero
        )
        
        for item in project.items {
            if rulesEngine.isCallApp(bundleId: item.bundleId, appName: item.appName) {
                continue // Protect call apps
            }
            
            guard let liveMatch = liveWindows.first(where: {
                ($0.bundleId?.caseInsensitiveCompare(item.bundleId) == .orderedSame ||
                 $0.appName.caseInsensitiveCompare(item.appName) == .orderedSame) &&
                $0.isStandardWindow
            }), let ax = liveMatch.axElement else {
                continue
            }
            
            // Resolve zone on target display
            let relativeRect: CGRect
            if let zoneId = item.zoneId,
               let zones = layout.displayZones[0],
               let zone = zones.first(where: { $0.id == zoneId }) {
                relativeRect = zone.relativeRect
            } else if let custom = item.customRelativeRect {
                relativeRect = custom
            } else {
                relativeRect = CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0)
            }
            
            let targetFrame = tilingEngine.calculateZoneFrame(on: targetDisplay, relativeRect: relativeRect)
            let res = windowManager.setWindowFrame(ax, to: targetFrame)
            switch res {
            case .success, .partial:
                movedCount += 1
            case .failed:
                break
            }
        }
        
        return AdaptationResult(
            wasAdapted: movedCount > 0,
            previousSignature: DisplaySignature(screenCount: lastKnownDisplayCount, resolutions: []),
            newSignature: DisplaySignature(screens: displays),
            windowsMovedCount: movedCount,
            appliedLayoutName: layout.displaySignature.description
        )
    }
    
    /// Simulates display disconnection (e.g. unplugs 4K monitor, leaving laptop screen)
    public func simulateDisplayDisconnect(for project: Project) -> AdaptationResult {
        let currentDisplays = displayManager.getDisplays()
        guard let primary = currentDisplays.first else {
            return AdaptationResult(
                wasAdapted: false,
                previousSignature: DisplaySignature(screens: currentDisplays),
                newSignature: DisplaySignature(screens: currentDisplays),
                windowsMovedCount: 0,
                appliedLayoutName: "None"
            )
        }
        
        // Single display remaining
        let remainingDisplays = [primary]
        let decision = rulesEngine.evaluateDisplayDisconnect(for: project, remainingDisplays: remainingDisplays)
        
        switch decision {
        case .applyAutomatically(let layout), .askUser(let layout, _):
            return applyLayout(layout, displays: remainingDisplays, for: project)
        case .doNothing:
            // Fall back to template halves
            let templateLayout = ProjectLayout(
                displaySignature: DisplaySignature(screens: remainingDisplays),
                displayZones: [0: Template.halves.zones]
            )
            return applyLayout(templateLayout, displays: remainingDisplays, for: project)
        }
    }
    
    /// Simulates display reconnection (e.g. replugs external 2560x1440 desk monitor)
    public func simulateDisplayReconnect(for project: Project) -> AdaptationResult {
        let currentDisplays = displayManager.getDisplays()
        
        // Pick the largest / multi-screen layout in project
        let deskLayout = project.layouts.values.first(where: { $0.displaySignature.screenCount > 1 }) ??
                         project.layouts.values.first
        
        guard let layout = deskLayout else {
            return AdaptationResult(
                wasAdapted: false,
                previousSignature: DisplaySignature(screens: currentDisplays),
                newSignature: DisplaySignature(screens: currentDisplays),
                windowsMovedCount: 0,
                appliedLayoutName: "None"
            )
        }
        
        return applyLayout(layout, displays: currentDisplays, for: project)
    }
}
