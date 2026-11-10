import SwiftUI
import Combine
import WispTileCore

public enum NavigationItem: String, CaseIterable, Identifiable {
    case projects
    case snapshots
    case rules
    case layouts
    case templateEditor
    case displays
    case snapping
    case repair
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .projects: return "Projects"
        case .snapshots: return "Snapshots"
        case .rules: return "Rules"
        case .layouts: return "Layouts"
        case .templateEditor: return "Template Editor"
        case .displays: return "Displays"
        case .snapping: return "Snapping and Spacing"
        case .repair: return "Repair Workspace"
        case .settings: return "Settings"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .projects: return "square.grid.2x2"
        case .snapshots: return "clock"
        case .rules: return "slider.horizontal.3"
        case .layouts: return "rectangle.split.2x2"
        case .templateEditor: return "square.grid.2x2"
        case .displays: return "display"
        case .snapping: return "rectangle.split.2x2"
        case .repair: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}

/// What happened when windows were tiled, so the UI can say why nothing moved.
public enum TileOutcome: Equatable {
    /// `tooWide`: apps that couldn't shrink to their zone, so they overlap the gaps.
    case tiled(Int, tooWide: [String])
    case noAccessibility
    case noWindows(elsewhere: Int)
}

@MainActor
public final class AppState: ObservableObject, UpdateNotificationDelegate {
    public static let shared = AppState()
    private static let onboardingCompletedKey = "WispTile.hasCompletedOnboarding"
    
    @Published public var selectedNav: NavigationItem = .projects {
        // Edit Project and the Restore Report are pages in the main window; leaving them via the sidebar closes them.
        didSet {
            if showingEditProjectSheet { showingEditProjectSheet = false }
            if showingRestoreReport { showingRestoreReport = false }
        }
    }
    /// Developer render harness only: keeps in-memory demo data from being reloaded from disk.
    public var suppressRefresh = false
    @Published public var projects: [Project] = []
    @Published public var selectedProject: Project?
    @Published public var templates: [Template] = []
    @Published public var snapshots: [Snapshot] = []
    @Published public var displays: [DisplayInfo] = []
    @Published public var settings: WispTileSettings = .default {
        didSet {
            try? storage.saveSettings(settings)
        }
    }
    
    // System & Permission Status
    @Published public var isAccessibilityGranted: Bool = false
    /// Pauses automatic tiling; "Pause Automation for 1 Hour" turns it back on after an hour.
    @Published public var isAutomationPaused: Bool = false {
        didSet {
            guard isAutomationPaused, !oldValue else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3600) { [weak self] in self?.isAutomationPaused = false }
        }
    }
    
    // Licensing & Updates
    public let updateManager = UpdateManager.shared
    
    // Sheet Presentations
    @Published public var showingCaptureSheet: Bool = false
    @Published public var showingEditProjectSheet: Bool = false
    @Published public var showingRestorePreview: Bool = false
    @Published public var showingRestoreReport: Bool = false
    @Published public var showingQuickSwitcher: Bool = false
    @Published public var showingWelcomeOnboarding: Bool = false
    @Published public var isOnboardingComplete: Bool = false
    @Published public var showingPermissionGuide: Bool = false
    @Published public var showingWindowPreviewPermission: Bool = false
    @Published public var showingUpdateWindowSheet: Bool = false
    @Published public var showingKeyboardShortcutsSheet: Bool = false
    
    // Slide-in update toast banner (Board 12)
    @Published public var showingUpdateNotificationBanner: Bool = false
    @Published public var backgroundUpdateInfo: UpdateInfo?
    
    /// Selected Settings tab (0 General, 1 Shortcuts, 2 License, 3 Updates).
    @Published public var settingsTab: Int = 0
    
    /// Shortcuts macOS refused to register (another app already uses them).
    @Published public var hotkeyConflicts: Set<String> = []
    
    /// Template the Template Editor should open next (set by "Edit Selected" on the Layouts tab).
    @Published public var templateToEdit: Template?
    
    // Restore states
    @Published public var projectToRestore: Project?
    @Published public var lastReport: RestoreReport?
    
    private let storage = StorageEngine.shared
    private let windowManager = WindowManager.shared
    private let displayManager = DisplayManager.shared
    private let restoreEngine = RestoreEngine.shared
    private let snapshotEngine = SnapshotEngine.shared
    
    public init() {
        self.settings = storage.loadSettings()
        // Migrate shortcuts shipped by pre-PRD builds. Bare Option combinations
        // interfere with typing characters such as ¡ and ™.
        if self.settings.quickSwitcherShortcut == "⌥Space" { self.settings.quickSwitcherShortcut = "⌃⌥Space" }
        if self.settings.captureShortcut == "⌥⇧C" { self.settings.captureShortcut = "⌃⌥C" }
        if self.settings.repairShortcut == "⌥R" { self.settings.repairShortcut = "⌃⌥R" }
        if self.settings.userName == "Your Name" || self.settings.userName.isEmpty {
            self.settings.userName = NSFullUserName()
        }
        if self.settings.userEmail == "you@example.com" { self.settings.userEmail = "" }
        storage.cleanupExpiredSnapshots() // Snapshots promises "kept for 30 days"
        refreshAll()
        updateManager.delegate = self
        isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
        showingWelcomeOnboarding = !isOnboardingComplete
    }

    public func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        isOnboardingComplete = true
        showingWelcomeOnboarding = false
    }
    
    public func refreshAll() {
        if suppressRefresh { return }
        isAccessibilityGranted = windowManager.isAccessibilityGranted()
        displays = displayManager.getDisplays()
        projects = storage.loadProjects()
        templates = storage.loadTemplates()
        snapshots = storage.loadSnapshots()
        
        if selectedProject == nil || !projects.contains(where: { $0.id == selectedProject?.id }) {
            selectedProject = projects.first
        }
    }
    
    /// Automation triggers derived from the user's real projects and settings.
    public var automationTriggers: [(whenText: String, actionText: String)] {
        var rows: [(String, String)] = []
        if displays.count > 1 || !projects.isEmpty {
            rows.append(("an external display connects", "Suggest At Desk layout"))
        }
        for p in projects {
            if let path = p.items.compactMap({ $0.pathOrURL }).first(where: { $0.hasPrefix("/") || $0.hasPrefix("~") }) {
                rows.append(("I open \((path as NSString).abbreviatingWithTildeInPath)", "Suggest \(p.name)"))
            }
        }
        rows.append(("a video call starts", "Pause tiling for 1 hour"))
        return rows
    }
    
    public var ruleCount: Int { automationTriggers.count + settings.excludedApps.appNames.count }
    
    /// Unique, stable display shortcut (⌃⌥1…⌃⌥9) for a project, de-duplicated by list order.
    public func displayShortcut(for project: Project) -> String? {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return project.shortcut }
        var used = Set<String>()
        for (i, p) in projects.enumerated() {
            var sc = p.shortcut
            if sc == nil || sc!.isEmpty || sc!.hasPrefix("⌥") || used.contains(sc!) { sc = i < 9 ? "⌃⌥\(i + 1)" : nil }
            if let s = sc, used.contains(s) { sc = nil }
            if let s = sc { used.insert(s) }
            if i == idx { return sc }
        }
        return nil
    }
    
    public func selectProject(_ project: Project) {
        selectedProject = project
        selectedNav = .projects
    }
    
    public func saveProject(_ project: Project) {
        try? storage.saveProject(project)
        LayoutPreviewStore.save(project: project)
        refreshAll()
        selectedProject = project
    }
    
    /// Arranges a project with a layout template (nil: windows come back as captured).
    /// Each app starts in the zone matching its place in the list.
    public func setLayout(_ template: Template?, for project: Project) {
        var p = project
        p.layoutTemplateId = template?.id
        for i in p.items.indices {
            p.items[i].templateZoneId = template.flatMap { TilingEngine.zone(for: ProjectItem(appName: "", bundleId: ""), index: i, in: $0)?.id }
        }
        p.updatedAt = Date()
        saveProject(p)
    }
    
    /// Built-in layouts plus the ones saved in the Template Editor.
    public var allTemplates: [Template] {
        Template.builtInPresets + templates.filter { t in !t.isBuiltIn && !Template.builtInPresets.contains(where: { $0.id == t.id }) }
    }
    
    public func deleteProject(_ project: Project) {
        storage.deleteProject(id: project.id)
        refreshAll()
    }
    
    public func triggerRestorePreview(for project: Project) {
        projectToRestore = project
        showingRestorePreview = true
    }
    
    public func executeRestore(for project: Project) async {
        showingRestorePreview = false
        let report = await restoreEngine.restore(project: project)
        lastReport = report
        showingRestoreReport = true
        refreshAll()
    }
    
    // MARK: - Dynamic Tiling Operations
    @discardableResult
    public func tileOpenWindows(presetName: String, takeSnapshot: Bool = true) -> TileOutcome {
        guard windowManager.isAccessibilityGranted() else {
            isAccessibilityGranted = false
            return .noAccessibility
        }
        let template = templates.first(where: { $0.name.caseInsensitiveCompare(presetName) == .orderedSame }) ??
                       Template.builtInPresets.first(where: { $0.name.caseInsensitiveCompare(presetName) == .orderedSame }) ??
                       Template.mainAndStack
        
        let allWindows = windowManager.getVisibleWindows()
        let ownBundle = Bundle.main.bundleIdentifier ?? "com.wisptile.WispTile"
        let targetWindows = allWindows.filter {
            $0.bundleId != ownBundle && $0.isStandardWindow && !$0.isMinimized &&
            !RulesEngine.shared.shouldExcludeFromTiling(bundleId: $0.bundleId, appName: $0.appName, title: $0.title)
        }
        
        guard !targetWindows.isEmpty else {
            return .noWindows(elsewhere: windowManager.countWindowsOffCurrentDesktop())
        }
        
        // Take auto-snapshot before tiling so it can be completely undone
        if takeSnapshot {
            _ = snapshotEngine.createSnapshot(name: "Before tiling: \(presetName)", kind: .autoBeforeRestore)
        }
        
        // Same zone rule as the Layouts preview: your zone choices first, then left to right.
        let choices = (UserDefaults.standard.string(forKey: "WispTile.newWindowZones")?.data(using: .utf8))
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        let zones = TilingEngine.assignZones(apps: targetWindows.map(\.appName), minX: targetWindows.map(\.frame.minX),
                                             template: template, choices: choices)
        let results = TilingEngine.shared.tileWindows(targetWindows, using: template, zoneIndices: zones)
        if takeSnapshot { refreshAll() }
        let moved = results.values.filter { if case .failed = $0 { return false }; return true }.count
        return .tiled(moved, tooWide: TilingEngine.shared.lastTooLargeApps)
    }
    
    @discardableResult
    public func tileActiveWindow(command: TilingCommand) -> WindowMoveResult {
        let allWindows = windowManager.getVisibleWindows()
        let ownBundle = Bundle.main.bundleIdentifier ?? "com.wisptile.WispTile"
        guard let target = allWindows.first(where: { ($0.bundleId != ownBundle) && $0.isStandardWindow }),
              let ax = target.axElement else {
            return .failed(error: "No active external window found to tile")
        }
        
        _ = snapshotEngine.createSnapshot(name: "Before \(command.rawValue)", kind: .autoBeforeRestore)
        let result = TilingEngine.shared.tileWindow(ax, command: command)
        refreshAll()
        return result
    }
    
    public func undoRestore() {
        _ = snapshotEngine.undoLastRestore()
        refreshAll()
    }
    
    public func undoRestore(snapshot: Snapshot) {
        _ = snapshotEngine.rollback(snapshot: snapshot)
        refreshAll()
    }
    
    public func takeSnapshot(name: String) {
        _ = snapshotEngine.createSnapshot(name: name, kind: .manual)
        refreshAll()
    }
    
    public func deleteSnapshot(_ snapshot: Snapshot) {
        storage.deleteSnapshot(id: snapshot.id)
        refreshAll()
    }
    
    // MARK: - Updates
    public func checkForUpdates(appClosed: Bool = false) async {
        if let update = await updateManager.checkForUpdates(isAppWindowClosed: appClosed) {
            self.backgroundUpdateInfo = update
            if appClosed {
                self.showingUpdateNotificationBanner = true
            }
        }
    }
    
    public func installAndRelaunch() async throws {
        try await updateManager.installAndRelaunch()
        self.backgroundUpdateInfo = nil
        self.showingUpdateNotificationBanner = false
        self.showingUpdateWindowSheet = false
    }
    
    public nonisolated func didDiscoverUpdateInBackground(_ update: UpdateInfo) {
        Task { @MainActor in
            self.backgroundUpdateInfo = update
            self.showingUpdateNotificationBanner = true
        }
    }
    
    // MARK: - Export
    public func exportProjectsAndTemplates() throws -> URL {
        return try storage.exportProjectsAndTemplates()
    }
}
