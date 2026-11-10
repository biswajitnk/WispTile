import XCTest
import CoreGraphics
@testable import WispTileCore

final class WispTileCoreTests: XCTestCase {
    
    var tempDirectory: URL!
    var storage: StorageEngine!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        storage = StorageEngine(customBaseDirectory: tempDirectory)
    }
    
    override func tearDown() {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        super.tearDown()
    }
    
    // MARK: - Template Engine Tests
    func testPresetTemplates() {
        let presets = Template.builtInPresets
        XCTAssertEqual(presets.count, 5)
        
        let halves = Template.halves
        XCTAssertEqual(halves.zones.count, 2)
        XCTAssertEqual(halves.zones[0].relativeRect.width, 0.5)
        XCTAssertEqual(halves.zones[1].relativeRect.width, 0.5)
        
        let mainStack = Template.mainAndStack
        XCTAssertEqual(mainStack.zones.count, 3)
        XCTAssertEqual(mainStack.zones[0].relativeRect.width, 0.6)
        XCTAssertEqual(mainStack.zones[1].relativeRect.width, 0.4)
        XCTAssertEqual(mainStack.zones[2].relativeRect.width, 0.4)
    }
    
    func testZoneSplitting() {
        let template = Template.halves
        let split = TemplateEngine.shared.splitZone(in: template, zoneId: "1", orientation: .horizontal, ratio: 0.5)
        
        XCTAssertEqual(split.zones.count, 3)
        let top = split.zones.first(where: { $0.id == "1" })!
        XCTAssertEqual(top.relativeRect.height, 0.5)
        XCTAssertEqual(top.relativeRect.width, 0.5)
    }
    
    func testZoneMerging() {
        let template = Template.halves
        let merged = TemplateEngine.shared.mergeZones(in: template, zoneId1: "1", zoneId2: "2")
        
        XCTAssertEqual(merged.zones.count, 1)
        XCTAssertEqual(merged.zones[0].relativeRect.width, 1.0)
        XCTAssertEqual(merged.zones[0].relativeRect.height, 1.0)
    }
    
    func testGridSnapping() {
        let raw = CGRect(x: 0.08, y: 0.12, width: 0.49, height: 0.51)
        let snapped = TemplateEngine.shared.snapToGrid(rect: raw, cols: 12, rows: 8)
        
        XCTAssertGreaterThan(snapped.origin.x, 0.0)
        XCTAssertLessThanOrEqual(snapped.origin.x + snapped.width, 1.0)
        XCTAssertLessThanOrEqual(snapped.origin.y + snapped.height, 1.0)
    }
    
    // MARK: - Storage Engine Tests
    func testProjectPersistence() throws {
        let project = Project(
            name: "Coding · SaaS",
            colorHex: "#4A2FC4",
            shortcut: "⌥1",
            items: [
                ProjectItem(appName: "VS Code", bundleId: "com.microsoft.VSCode", pathOrURL: "~/dev/saas-app"),
                ProjectItem(appName: "Terminal", bundleId: "com.apple.Terminal", pathOrURL: "~/dev/saas-app")
            ]
        )
        
        try storage.saveProject(project)
        let loaded = storage.loadProject(id: project.id)
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Coding · SaaS")
        XCTAssertEqual(loaded?.shortcut, "⌥1")
        XCTAssertEqual(loaded?.items.count, 2)
        XCTAssertEqual(loaded?.items[0].appName, "VS Code")
        
        storage.deleteProject(id: project.id)
        XCTAssertNil(storage.loadProject(id: project.id))
    }
    
    func testSnapshotRetention() throws {
        let signature = DisplaySignature(screenCount: 1, resolutions: [CGSize(width: 1440, height: 900)])
        
        let freshSnapshot = Snapshot(
            name: "Recent Snapshot",
            timestamp: Date(),
            displaySignature: signature,
            windows: []
        )
        let oldSnapshot = Snapshot(
            name: "Old Snapshot",
            timestamp: Date().addingTimeInterval(-31 * 24 * 60 * 60), // 31 days old
            displaySignature: signature,
            windows: []
        )
        
        try storage.saveSnapshot(freshSnapshot)
        try storage.saveSnapshot(oldSnapshot)
        
        XCTAssertTrue(oldSnapshot.isExpired)
        XCTAssertFalse(freshSnapshot.isExpired)
        
        storage.cleanupExpiredSnapshots()
        let remaining = storage.loadSnapshots()
        
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].id, freshSnapshot.id)
    }
    
    // MARK: - Snap Command Detection Tests
    @MainActor
    func testEdgeSnapDetection() {
        let display = DisplayInfo(
            id: 1, name: "Screen", isPrimary: true, isBuiltIn: true, hasNotch: false, safeAreaTopInset: 0,
            cocoaFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            cocoaVisibleFrame: CGRect(x: 0, y: 30, width: 1440, height: 870),
            axFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            axVisibleFrame: CGRect(x: 0, y: 30, width: 1440, height: 870)
        )
        
        let leftSnap = TilingEngine.shared.detectSnapCommand(mouseLocation: CGPoint(x: 5, y: 400), display: display)
        XCTAssertEqual(leftSnap, .leftHalf)
        
        let rightSnap = TilingEngine.shared.detectSnapCommand(mouseLocation: CGPoint(x: 1435, y: 400), display: display)
        XCTAssertEqual(rightSnap, .rightHalf)
        
        let topSnap = TilingEngine.shared.detectSnapCommand(mouseLocation: CGPoint(x: 700, y: 35), display: display)
        XCTAssertEqual(topSnap, .maximize)
        
        let cornerSnap = TilingEngine.shared.detectSnapCommand(mouseLocation: CGPoint(x: 10, y: 35), display: display)
        XCTAssertEqual(cornerSnap, .topLeftQuadrant)
    }
    
    // MARK: - Phase 2 Capture Workflow Tests
    @MainActor
    func testCaptureProjectGeneration() throws {
        let windows: [CapturedWindow] = [
            CapturedWindow(
                id: 101, pid: 501, appName: "VS Code", bundleId: "com.microsoft.VSCode",
                title: "saas-app — index.ts", displayIndex: 0,
                relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.6, height: 1.0),
                detectedPathOrURL: "saas-app", isCallApp: false, isSelected: true
            ),
            CapturedWindow(
                id: 102, pid: 502, appName: "Chrome", bundleId: "com.google.Chrome",
                title: "localhost:3000 — Dashboard", displayIndex: 0,
                relativeRect: CGRect(x: 0.6, y: 0.0, width: 0.4, height: 0.5),
                detectedPathOrURL: "localhost:3000", isCallApp: false, isSelected: true
            ),
            CapturedWindow(
                id: 103, pid: 503, appName: "Terminal", bundleId: "com.apple.Terminal",
                title: "~/dev/saas-app", displayIndex: 0,
                relativeRect: CGRect(x: 0.6, y: 0.5, width: 0.4, height: 0.5),
                detectedPathOrURL: "~/dev/saas-app", isCallApp: false, isSelected: true
            )
        ]
        
        let project = CaptureEngine.shared.captureProject(
            name: "Coding · SaaS",
            shortcut: "⌥1",
            selectedWindows: windows
        )
        
        XCTAssertEqual(project.name, "Coding · SaaS")
        XCTAssertEqual(project.shortcut, "⌥1")
        XCTAssertEqual(project.items.count, 3)
        XCTAssertEqual(project.items[0].appName, "VS Code")
        XCTAssertEqual(project.items[1].appName, "Chrome")
        XCTAssertEqual(project.items[2].appName, "Terminal")
        
        try storage.saveProject(project)
        let loaded = storage.loadProject(id: project.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.items.count, 3)
    }
    
    // MARK: - Phase 3 Display Adaptation & Safety Tests
    @MainActor
    func testDisplayAdaptationSimulation() {
        let deskSignature = DisplaySignature(screenCount: 2, resolutions: [CGSize(width: 2560, height: 1440), CGSize(width: 1512, height: 982)])
        let laptopSignature = DisplaySignature(screenCount: 1, resolutions: [CGSize(width: 1512, height: 982)])
        
        let deskLayout = ProjectLayout(
            displaySignature: deskSignature,
            displayZones: [
                0: [Zone(id: "z1", name: "Wide Editor", relativeRect: CGRect(x: 0, y: 0, width: 0.6, height: 1.0))],
                1: [Zone(id: "z2", name: "Laptop Browser", relativeRect: CGRect(x: 0, y: 0, width: 1.0, height: 1.0))]
            ]
        )
        let laptopLayout = ProjectLayout(
            displaySignature: laptopSignature,
            displayZones: [
                0: [
                    Zone(id: "z1", name: "Left Half", relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0)),
                    Zone(id: "z2", name: "Right Half", relativeRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0))
                ]
            ]
        )
        
        let project = Project(
            name: "Adaptation Test Project",
            items: [
                ProjectItem(appName: "VS Code", bundleId: "com.microsoft.VSCode", displayIndex: 0, zoneId: "z1"),
                ProjectItem(appName: "Chrome", bundleId: "com.google.Chrome", displayIndex: 1, zoneId: "z2")
            ],
            layouts: [
                deskSignature.rawValue: deskLayout,
                laptopSignature.rawValue: laptopLayout
            ]
        )
        
        // 1. Simulate Display Disconnect
        let disconnectResult = DisplayAdaptationEngine.shared.simulateDisplayDisconnect(for: project)
        XCTAssertEqual(disconnectResult.newSignature.screenCount, 1)
        
        // 2. Simulate Display Reconnect
        let reconnectResult = DisplayAdaptationEngine.shared.simulateDisplayReconnect(for: project)
        XCTAssertNotNil(reconnectResult.appliedLayoutName)
    }
    
    func testShortcutConflictDetector() {
        let conflict = ShortcutConflictDetector.shared.checkConflict(for: "⌥R")
        XCTAssertNotNil(conflict)
        XCTAssertEqual(conflict?.severity, .warning)
        XCTAssertTrue(conflict?.conflictingAppOrFeature.contains("Screen Recording") ?? false)
        
        let spotlightConflict = ShortcutConflictDetector.shared.checkConflict(for: "⌘Space")
        XCTAssertNotNil(spotlightConflict)
        XCTAssertTrue(spotlightConflict?.conflictingAppOrFeature.contains("Spotlight") ?? false)
        
        let unconflicted = ShortcutConflictDetector.shared.checkConflict(for: "⌥1")
        XCTAssertNil(unconflicted)
    }
    
    @MainActor
    func testRulesEngineCallProtection() {
        XCTAssertTrue(RulesEngine.shared.isCallApp(bundleId: "us.zoom.xos", appName: "Zoom"))
        XCTAssertTrue(RulesEngine.shared.isCallApp(bundleId: "com.apple.FaceTime", appName: "FaceTime"))
        XCTAssertTrue(RulesEngine.shared.isCallApp(bundleId: nil, appName: "Google Meet"))
        XCTAssertTrue(RulesEngine.shared.isCallApp(bundleId: nil, appName: "Slack", title: "Engineering Huddle"))
        
        XCTAssertFalse(RulesEngine.shared.isCallApp(bundleId: "com.microsoft.VSCode", appName: "VS Code"))
        XCTAssertFalse(RulesEngine.shared.isCallApp(bundleId: "com.apple.Terminal", appName: "Terminal"))
    }
    
    
    func testUpdateManagerAndReleaseNotes() async throws {
        // No update feed is published yet, so a check must report "up to date" rather than a made-up release.
        let updateManager = UpdateManager(currentVersion: "1.3.2")
        let update = await updateManager.checkForUpdates(isAppWindowClosed: false)
        XCTAssertNil(update)
        XCTAssertNil(updateManager.availableUpdate)
        
        // Installing with nothing available is a no-op.
        try await updateManager.installAndRelaunch()
        XCTAssertEqual(updateManager.currentVersion, "1.3.2")
        
        // Version comparison used when a real feed arrives.
        XCTAssertTrue(updateManager.isVersionNewer("1.4", than: "1.3.2"))
        XCTAssertTrue(updateManager.isVersionNewer("1.10", than: "1.9"))
        XCTAssertFalse(updateManager.isVersionNewer("1.3.2", than: "1.3.2"))
        XCTAssertFalse(updateManager.isVersionNewer("1.3", than: "1.3.0"))
        
        // The sample release notes still group correctly for the update window.
        let sample = UpdateInfo.sample1_4
        XCTAssertEqual(sample.releaseNotes.filter { $0.category == .new }.count, 2)
        XCTAssertEqual(sample.releaseNotes.filter { $0.category == .improved }.count, 2)
        XCTAssertEqual(sample.releaseNotes.filter { $0.category == .fixed }.count, 1)
    }
    
    func testProjectAndTemplateExport() throws {
        let project = Project(name: "Export Test Project")
        try storage.saveProject(project)
        
        let exportURL = try storage.exportProjectsAndTemplates()
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        
        let data = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(StorageEngine.ExportBundle.self, from: data)
        XCTAssertGreaterThanOrEqual(bundle.projects.count, 1)
        XCTAssertGreaterThanOrEqual(bundle.templates.count, 5)
        
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    // MARK: - Phase 5 Beta & Hardening Tests
    
    func testHardwareMatrixAudit() {
        let (passed, reports) = HardwareMatrixEngine.shared.auditHardwareMatrix()
        XCTAssertTrue(passed, "Hardware matrix audit should pass for all 7 Mac profiles")
        XCTAssertEqual(reports.count, 7)
    }
    
    func testNotchSafetyWindowClamping() {
        let mbp14 = HardwareProfile.macBookPro14
        
        // Window illegally placed behind notch / menu bar
        let illegalFrame = CGRect(x: 200, y: 10, width: 600, height: 400)
        let validation = HardwareMatrixEngine.shared.validateWindowPlacement(windowFrame: illegalFrame, on: mbp14)
        
        XCTAssertFalse(validation.isValid, "Window at y=10 should violate menu bar / notch safe area")
        XCTAssertTrue(validation.violations.contains(where: { $0.contains("intrudes into menu bar") }))
        XCTAssertGreaterThanOrEqual(validation.clampedFrame.origin.y, mbp14.safeAreaTopInset)
        
        // Tiled frame should automatically clear notch
        let safeTiled = HardwareMatrixEngine.shared.calculateTiledRect(
            on: mbp14,
            relativeRect: CGRect(x: 0, y: 0, width: 0.5, height: 1.0)
        )
        let safeValidation = HardwareMatrixEngine.shared.validateWindowPlacement(windowFrame: safeTiled, on: mbp14)
        XCTAssertTrue(safeValidation.isValid)
    }
    
    func testCompatibilityMatrixProfiles() {
        let engine = CompatibilityEngine.shared
        let (total, categories) = engine.auditCompatibilityMatrix()
        
        XCTAssertGreaterThanOrEqual(total, 20)
        XCTAssertGreaterThanOrEqual(categories[.browser] ?? 0, 4)
        XCTAssertGreaterThanOrEqual(categories[.codeEditor] ?? 0, 5)
        XCTAssertGreaterThanOrEqual(categories[.terminal] ?? 0, 4)
        XCTAssertGreaterThanOrEqual(categories[.electron] ?? 0, 5)
        XCTAssertGreaterThanOrEqual(categories[.callApp] ?? 0, 4)
        
        let vscode = engine.profile(forBundleId: "com.microsoft.VSCode")
        XCTAssertNotNil(vscode)
        XCTAssertTrue(vscode?.supportsFolderLaunch == true)
        
        let chrome = engine.profile(forBundleId: "com.google.Chrome")
        XCTAssertNotNil(chrome)
        XCTAssertTrue(chrome?.supportsURLRestore == true)
    }
    
    func testActiveCallProtectionEvaluation() {
        let engine = CompatibilityEngine.shared
        
        let zoom = engine.evaluateWindow(appName: "Zoom", bundleId: "us.zoom.xos", windowTitle: "Zoom Meeting - Standup")
        XCTAssertFalse(zoom.shouldTile)
        XCTAssertTrue(zoom.isCallProtected)
        XCTAssertNotNil(zoom.skipReason)
        
        let ft = engine.evaluateWindow(appName: "FaceTime", bundleId: "com.apple.FaceTime", windowTitle: "Call in progress")
        XCTAssertFalse(ft.shouldTile)
        XCTAssertTrue(ft.isCallProtected)
        
        let regularSlack = engine.evaluateWindow(appName: "Slack", bundleId: "com.tinyspeck.slackmacgap", windowTitle: "#general")
        XCTAssertTrue(regularSlack.shouldTile)
        XCTAssertFalse(regularSlack.isCallProtected)
    }
    
    func testStubbornAndDialogWindowSkipping() {
        let engine = CompatibilityEngine.shared
        
        let sysPref = engine.evaluateWindow(appName: "System Settings", bundleId: "com.apple.systempreferences", windowTitle: "General")
        XCTAssertFalse(sysPref.shouldTile)
        XCTAssertTrue(sysPref.skipReason?.contains("System Settings") == true)
        
        let dialog = engine.evaluateWindow(appName: "Safari", bundleId: "com.apple.Safari", windowTitle: "Preferences")
        XCTAssertFalse(dialog.shouldTile)
        XCTAssertTrue(dialog.skipReason?.contains("Preferences") == true)
        
        let nonResizable = engine.evaluateWindow(appName: "CustomApp", bundleId: "com.custom.app", windowTitle: "Tool", isResizable: false)
        XCTAssertFalse(nonResizable.shouldTile)
        XCTAssertTrue(nonResizable.skipReason?.contains("does not support resize") == true)
    }
    
    func testDiagnosticsBundleSanitization() {
        let engine = DiagnosticsEngine.shared
        
        let rawLog = "Error accessing /Users/alice/Library/Preferences/secret.plist. Contact user alice.smith@corp.com with key WR-1234-5678-9012-3456"
        let sanitized = engine.sanitize(rawLog)
        
        XCTAssertFalse(sanitized.contains("/Users/alice"))
        XCTAssertTrue(sanitized.contains("~/Library/Preferences"))
        XCTAssertFalse(sanitized.contains("alice.smith@corp.com"))
        XCTAssertTrue(sanitized.contains("[REDACTED-EMAIL]"))
        XCTAssertFalse(sanitized.contains("WR-1234-5678-9012-3456"))
        XCTAssertTrue(sanitized.contains("WR-••••-••••-••••"))
        
        let bundle = engine.generateBundle()
        XCTAssertFalse(bundle.systemInfo.osVersion.isEmpty)
        XCTAssertGreaterThan(bundle.displays.count, 0)
        XCTAssertGreaterThanOrEqual(bundle.healthStats.crashFreeSessionRate, 99.0)
    }
    
    func testCrashFreeSessionMetric() {
        let engine = DiagnosticsEngine.shared
        let rate = engine.crashFreeRate
        XCTAssertGreaterThanOrEqual(rate, 99.0, "Crash free rate must meet or exceed PRD target of 99.0%")
    }
    
    func testAtomicPersistenceUnderConcurrentLoad() throws {
        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("WispTile-AtomicTest-\(UUID().uuidString)")
        let engine = StorageEngine(customBaseDirectory: tempBase)
        
        let count = 25
        for i in 1...count {
            let p = Project(name: "Project #\(i)", shortcut: "⌥\(i % 9)")
            try engine.saveProject(p)
        }
        
        let loaded = engine.loadProjects()
        XCTAssertEqual(loaded.count, count)
        
        try? FileManager.default.removeItem(at: tempBase)
    }
}
