import SwiftUI
import AppKit
import WispTileCore

/// Developer tool: `WISPTILE_RENDER=<dir> WispTileApp` renders each main screen to a PNG and exits.
@MainActor
enum RenderHarness {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["WISPTILE_RENDER"] else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        NSApp.appearance = NSAppearance(named: .aqua)
        let state = AppState.shared
        let navs: [NavigationItem] = [.projects, .layouts, .snapping, .templateEditor, .snapshots, .rules, .displays, .settings]
        for nav in navs {
            state.selectedNav = nav
            render(MainContainerView(appState: state).frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/\(nav.rawValue).png")
        }
        render(MenuBarPopoverView(appState: state).frame(width: 380, height: 830), size: CGSize(width: 380, height: 830), to: "\(dir)/18_menubar.png")
        // Demo project (in-memory only) to check the populated dashboard
        let demo = Project(name: "Coding · SaaS Project", colorHex: "#5B5BD6", shortcut: "⌃⌥1", items: [
            ProjectItem(appName: "Safari", bundleId: "com.apple.Safari", pathOrURL: "localhost:3000", customRelativeRect: CGRect(x: 0, y: 0, width: 0.59, height: 1)),
            ProjectItem(appName: "Terminal", bundleId: "com.apple.Terminal", pathOrURL: "~/dev/saas-app", customRelativeRect: CGRect(x: 0.61, y: 0, width: 0.39, height: 0.49)),
            ProjectItem(appName: "Notes", bundleId: "com.apple.Notes", customRelativeRect: CGRect(x: 0.61, y: 0.51, width: 0.39, height: 0.49)),
        ])
        LayoutPreviewStore.save(project: demo)
        state.projects = [demo]; state.selectedProject = demo; state.selectedNav = .projects
        render(MainContainerView(appState: state).frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/demo_projects.png")
        try? FileManager.default.removeItem(at: StorageEngine.shared.previewURL(for: demo.id))
        // Section B (Projects · Recall) boards with three in-memory demo projects
        state.suppressRefresh = true
        let demo2 = Project(name: "Content · Multi-Screen", colorHex: "#AF52DE", items: [
            ProjectItem(appName: "Safari", bundleId: "com.apple.Safari", pathOrURL: "https://developer.apple.com", customRelativeRect: CGRect(x: 0, y: 0, width: 0.69, height: 1)),
            ProjectItem(appName: "Notes", bundleId: "com.apple.Notes", customRelativeRect: CGRect(x: 0.71, y: 0, width: 0.29, height: 1)),
        ])
        let demo3 = Project(name: "Android · App Build", colorHex: "#30B552", items: [
            ProjectItem(appName: "Terminal", bundleId: "com.apple.Terminal", pathOrURL: "~/dev/android-app", customRelativeRect: CGRect(x: 0, y: 0, width: 1, height: 1)),
        ])
        state.projects = [demo, demo2, demo3]; state.selectedProject = demo
        let shell: (String) -> Void = { name in
            render(MainContainerView(appState: state).frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/B_\(name).png")
        }
        state.selectedNav = .projects; shell("05_projects")
        state.showingEditProjectSheet = true; shell("07_edit_project"); state.showingEditProjectSheet = false
        var arranged = demo; arranged.layoutTemplateId = Template.thirds.id
        state.projects = [arranged, demo2, demo3]; state.selectedProject = arranged
        state.selectedNav = .projects; shell("05b_projects_arranged")
        state.showingEditProjectSheet = true; shell("07b_edit_arranged"); state.showingEditProjectSheet = false
        state.projects = [demo, demo2, demo3]; state.selectedProject = demo
        state.selectedNav = .repair; shell("10_repair")
        if let d = DisplayManager.shared.getDisplays().first {
            let v = d.axVisibleFrame
            let target = CGRect(x: v.minX, y: v.minY, width: v.width * 0.59, height: v.height)
            let current = CGRect(x: v.minX + v.width * 0.09, y: v.minY + v.height * 0.09, width: v.width * 0.50, height: v.height * 0.84)
            let drift = DriftReport(projectId: demo.id, projectName: demo.name, driftedWindows: [
                DriftedWindow(windowId: 1, appName: "Safari", bundleId: "com.apple.Safari", title: "", zoneId: "left", zoneName: "Left",
                              targetFrame: target, currentFrame: current,
                              driftDescription: "About 9% to the right and 9% narrower than its saved zone.", isWrongDisplay: false)
            ], totalWindowsChecked: 3)
            let repair = HStack(spacing: 0) { SidebarView(appState: state); RepairWorkspaceView(appState: state, previewReport: drift) }
            render(repair.frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/B_10_repair_demo.png")
        }
        state.selectedNav = .snapshots; shell("11_snapshots")
        state.selectedNav = .rules; shell("12_rules")
        let savedProjects = state.projects
        state.projects = []; state.selectedProject = nil; state.selectedNav = .projects; shell("13_empty")
        state.projects = savedProjects; state.selectedProject = demo
        render(CaptureDesktopSheet(appState: state, isPresented: .constant(true)).frame(width: 880, height: 640), size: CGSize(width: 880, height: 640), to: "\(dir)/B_06_capture.png")
        render(RestorePreviewSheet(appState: state, project: demo, isPresented: .constant(true)), size: CGSize(width: 900, height: 640), to: "\(dir)/B_08_restore_preview.png")
        try? FileManager.default.removeItem(at: StorageEngine.shared.previewURL(for: demo.id))
        // Section C (Automatic tiling) boards
        let desk = ProjectLayout(displaySignature: DisplaySignature(screenCount: 2, resolutions: [CGSize(width: 2560, height: 1440), CGSize(width: 1512, height: 982)]))
        let laptop = ProjectLayout(displaySignature: DisplaySignature(screenCount: 1, resolutions: [CGSize(width: 1512, height: 982)]))
        var demoC = demo
        demoC.items.append(ProjectItem(appName: "Slack", bundleId: "com.tinyspeck.slackmacgap", displayIndex: 1, customRelativeRect: CGRect(x: 0.03, y: 0.08, width: 0.94, height: 0.84)))
        demoC.layouts = ["desk": desk, "laptop": laptop]
        state.projects = [demoC, demo2, demo3]; state.selectedProject = demoC
        state.selectedNav = .layouts; shell("14_layouts")
        state.selectedNav = .templateEditor; shell("15_template_editor")
        state.selectedNav = .snapping; shell("16_snapping")
        state.selectedNav = .displays; shell("17_displays")
        // Size sweep: every main screen at the window's minimum size and at a large full-screen size
        if ProcessInfo.processInfo.environment["WISPTILE_RENDER_SIZES"] != nil {
            let sizes: [(String, CGSize)] = [("min", CGSize(width: 820, height: 560)), ("max", CGSize(width: 2056, height: 1290))]
            let screens: [(String, () -> Void)] = [
                ("projects", { state.selectedNav = .projects }),
                ("edit", { state.selectedNav = .projects; state.showingEditProjectSheet = true }),
                ("report", { state.selectedNav = .projects; state.lastReport = state.lastReport; state.showingRestoreReport = state.lastReport != nil }),
                ("snapshots", { state.selectedNav = .snapshots }),
                ("rules", { state.selectedNav = .rules }),
                ("repair", { state.selectedNav = .repair }),
                ("layouts", { state.selectedNav = .layouts }),
                ("template", { state.selectedNav = .templateEditor }),
                ("snapping", { state.selectedNav = .snapping }),
                ("displays", { state.selectedNav = .displays }),
                ("settings0", { state.selectedNav = .settings; state.settingsTab = 0 }),
                ("settings1", { state.selectedNav = .settings; state.settingsTab = 1 }),
                ("settings2", { state.selectedNav = .settings; state.settingsTab = 2 }),
            ]
            for (sizeName, size) in sizes {
                for (name, setup) in screens {
                    state.showingEditProjectSheet = false; state.showingRestoreReport = false
                    setup()
                    render(MainContainerView(appState: state).frame(width: size.width, height: size.height), size: size, to: "\(dir)/Z_\(sizeName)_\(name).png")
                }
            }
            state.showingEditProjectSheet = false; state.showingRestoreReport = false; state.settingsTab = 0
            let empty = state.projects; state.projects = []; state.selectedProject = nil; state.selectedNav = .projects
            for (sizeName, size) in sizes {
                render(MainContainerView(appState: state).frame(width: size.width, height: size.height), size: size, to: "\(dir)/Z_\(sizeName)_empty.png")
            }
            state.projects = empty; state.selectedProject = empty.first
        }
        // Section D with demo projects
        render(MenuBarPopoverView(appState: state).frame(width: 380), size: CGSize(width: 380, height: 830), to: "\(dir)/D_18_menubar.png")
        state.backgroundUpdateInfo = UpdateInfo.sample1_4
        state.selectedNav = .settings
        for tab in 0...2 { state.settingsTab = tab; shell("D_settings_\(tab)") }
        state.settingsTab = 0
        state.backgroundUpdateInfo = nil
        state.suppressRefresh = false
        state.refreshAll()

        // Real window with the main-window chrome, to check the traffic lights sit in the sidebar band
        renderWindow(MainContainerView(appState: state), size: CGSize(width: 1280, height: 800), to: "\(dir)/S_window_chrome.png")

        // narrow-window check
        for nav in [NavigationItem.projects, .layouts, .settings, .displays] {
            state.selectedNav = nav
            render(MainContainerView(appState: state).frame(width: 860, height: 640), size: CGSize(width: 860, height: 640), to: "\(dir)/narrow_\(nav.rawValue).png")
        }
        let t = Binding.constant(true)
        let reportItems = [
            RestoreReportItem(appName: "VS Code", bundleId: "com.microsoft.VSCode", status: "Restored", detail: "Reused the open window, placed in the editor zone", targetFrame: .zero, actualFrame: .zero, isReused: true),
            RestoreReportItem(appName: "Terminal", bundleId: "com.apple.Terminal", status: "Restored", detail: "Opened at ~/dev/saas-app, started npm run dev", targetFrame: .zero, actualFrame: .zero, isReused: true),
            RestoreReportItem(appName: "Chrome tabs", bundleId: "com.google.Chrome", status: "Needs you", detail: "docs.stripe.com needs your Work profile, which is signed out.", targetFrame: .zero, actualFrame: nil, isReused: true),
            RestoreReportItem(appName: "Zoom", bundleId: "us.zoom.xos", status: "Skipped", detail: "Skipped on purpose. You were in a call.", targetFrame: .zero, actualFrame: nil, isReused: true),
        ]
        let sampleSnapshot = Snapshot(name: "Before Coding restore", displaySignature: DisplaySignature(screenCount: 1, resolutions: [CGSize(width: 1440, height: 900)]), windows: [])
        let sampleReport = RestoreReport(projectId: demo.id, projectName: "Coding", duration: 3.2, items: reportItems, successCount: 5, warningCount: 2, skippedCount: 1, snapshot: sampleSnapshot, passed: false)
        state.suppressRefresh = true
        state.projects = [demo]; state.selectedProject = demo; state.lastReport = sampleReport
        state.selectedNav = .projects; state.showingRestoreReport = true
        render(MainContainerView(appState: state).frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/B_09_restore_report.png")
        if ProcessInfo.processInfo.environment["WISPTILE_RENDER_SIZES"] != nil {
            render(MainContainerView(appState: state).frame(width: 820, height: 560), size: CGSize(width: 820, height: 560), to: "\(dir)/Z_min_report.png")
        }
        state.showingRestoreReport = false; state.suppressRefresh = false; state.refreshAll()
        let sheets: [(String, AnyView, CGSize)] = [
            ("06_capture", AnyView(CaptureDesktopSheet(appState: state, isPresented: t)), CGSize(width: 880, height: 640)),
            ("01_welcome", AnyView(WelcomeView(appState: state, isPresented: t)), CGSize(width: 720, height: 560)),
            ("02_permission", AnyView(PermissionGuideView(appState: state, isPresented: t)), CGSize(width: 720, height: 560)),
            ("03_window_previews", AnyView(WindowPreviewPermissionView(appState: state, isPresented: t)), CGSize(width: 720, height: 560)),
            ("shortcuts", AnyView(KeyboardShortcutsView(appState: state)), CGSize(width: 640, height: 560)),
            ("08_restorepreview", AnyView(RestorePreviewSheet(appState: state, project: state.projects.first ?? demo, isPresented: t)), CGSize(width: 720, height: 600)),
            ("09_restorereport", AnyView(RestoreReportSheet(appState: state, report: sampleReport, isPresented: t)), CGSize(width: 960, height: 650)),
            ("repair", AnyView(RepairWorkspaceView(appState: state).frame(width: 1000, height: 600)), CGSize(width: 1000, height: 600)),
            ("editproject", AnyView(EditProjectView(appState: state, isPresented: t)), CGSize(width: 720, height: 680)),
            ("empty", AnyView(EmptyStateView(appState: state)), CGSize(width: 1000, height: 700)),
        ]
        for (name, v, size) in sheets {
            render(v.frame(width: size.width, height: size.height).background(Color.white), size: size, to: "\(dir)/sheet_\(name).png")
        }

        state.selectedNav = .settings
        for tab in 0...2 {
            let shell = HStack(spacing: 0) {
                SidebarView(appState: state)
                SettingsView(appState: state, initialTab: tab)
            }
            let board = 19 + tab
            render(shell.frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/\(board)_settings_tab_\(tab).png")
        }

        let problems = ErrorsAndEdgeCasesView(appState: state)
        render(problems.frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/25_problems.png")

        let update = UpdateInfo.sample1_4
        let notice = ZStack(alignment: .topTrailing) {
            Color(hex: 0xF5F5F7)
            UpdateNotificationBanner(appState: state, update: update, onUpdateNow: {}, onDismiss: {}, onWhatsNew: {})
                .padding(.top, 24).padding(.trailing, 24)
        }
        render(notice.frame(width: 1280, height: 800), size: CGSize(width: 1280, height: 800), to: "\(dir)/24_update_notice.png")
        render(UpdateWindowView(appState: state, isPresented: t), size: CGSize(width: 720, height: 560), to: "\(dir)/23_update_window.png")
        exit(0)
    }

    /// Renders inside a titled window with the main-window chrome applied, including the traffic lights.
    static func renderWindow<V: View>(_ view: V, size: CGSize, to path: String) {
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        MainWindowChrome.apply(to: window)
        window.contentView = NSHostingView(rootView: view)
        window.setContentSize(size)
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        guard let frameView = window.contentView?.superview else { return }
        frameView.layoutSubtreeIfNeeded()
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
        window.orderOut(nil)
    }
    
    static func render<V: View>(_ view: V, size: CGSize, to path: String) {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
    }
}
