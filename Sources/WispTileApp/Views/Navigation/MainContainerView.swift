import SwiftUI
import WispTileCore

public struct MainContainerView: View {
    @ObservedObject var appState: AppState
    /// True while the main window is in macOS full screen.
    @State private var isFullScreen = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Shared Sidebar
                SidebarView(appState: appState, showsWindowControlsBand: !isFullScreen)
                
                // Content View
                VStack(spacing: 0) {
                    Group {
                        if appState.showingEditProjectSheet {
                            // Board 7: Edit Project is a page beside the sidebar, not a sheet.
                            EditProjectView(appState: appState, isPresented: $appState.showingEditProjectSheet)
                                .id(appState.selectedProject?.id)
                        } else if appState.showingRestoreReport, let report = appState.lastReport {
                            // Board 9: the Restore Report is a page beside the sidebar.
                            RestoreReportSheet(appState: appState, report: report, isPresented: $appState.showingRestoreReport)
                        } else {
                        switch appState.selectedNav {
                        case .projects:
                            ProjectsDetailView(appState: appState)
                        case .layouts:
                            AutomaticTilingView(appState: appState)
                        case .templateEditor:
                            CustomTemplateEditorView(appState: appState)
                        case .displays:
                            MonitorAdaptationView(appState: appState)
                        case .rules:
                            RulesView(appState: appState)
                        case .snapshots:
                            SnapshotsView(appState: appState)
                        case .repair:
                            RepairWorkspaceView(appState: appState)
                        case .snapping:
                            SnappingAndSpacingView(appState: appState)
                        case .settings:
                            SettingsView(appState: appState)
                        }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Quick Switcher Floating Overlay
            if appState.showingQuickSwitcher {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.showingQuickSwitcher = false
                    }
                
                QuickSwitcherOverlay(appState: appState, isPresented: $appState.showingQuickSwitcher)
            }
            
            // Board 12: Slide-in background update notification toast
            if appState.showingUpdateNotificationBanner, let update = appState.backgroundUpdateInfo {
                VStack {
                    HStack {
                        Spacer()
                        UpdateNotificationBanner(
                            appState: appState,
                            update: update,
                            onUpdateNow: {
                                appState.showingUpdateNotificationBanner = false
                                appState.showingUpdateWindowSheet = true
                            },
                            onDismiss: {
                                withAnimation {
                                    appState.showingUpdateNotificationBanner = false
                                }
                            },
                            onWhatsNew: {
                                appState.showingUpdateNotificationBanner = false
                                appState.showingUpdateWindowSheet = true
                            }
                        )
                        .padding(.top, 24)
                        .padding(.trailing, 24)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        // The sidebar and each toolbar start at the very top, under the transparent title bar.
        // In a normal window the content runs under the transparent title bar. In full screen macOS
        // draws that bar opaque, so the content must start below it instead of being covered.
        .ignoresSafeArea(.container, edges: isFullScreen ? [] : .top)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.isAccessibilityGranted = WindowManager.shared.isAccessibilityGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { note in
            guard let w = note.object as? NSWindow, w.toolbar?.identifier == "WispTileMainWindow" else { return }
            w.toolbar?.isVisible = false
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { note in
            guard let w = note.object as? NSWindow, w.toolbar?.identifier == "WispTileMainWindow" else { return }
            w.toolbar?.isVisible = true
            isFullScreen = false
        }
        // Sheets
        .sheet(isPresented: $appState.showingCaptureSheet) {
            CaptureDesktopSheet(appState: appState, isPresented: $appState.showingCaptureSheet)
        }
        .sheet(isPresented: $appState.showingRestorePreview) {
            if let project = appState.projectToRestore {
                RestorePreviewSheet(appState: appState, project: project, isPresented: $appState.showingRestorePreview)
            }
        }
        .sheet(isPresented: $appState.showingWelcomeOnboarding) {
            WelcomeView(appState: appState, isPresented: $appState.showingWelcomeOnboarding)
        }
        .sheet(isPresented: $appState.showingPermissionGuide) {
            PermissionGuideView(appState: appState, isPresented: $appState.showingPermissionGuide)
        }
        .sheet(isPresented: $appState.showingWindowPreviewPermission) {
            WindowPreviewPermissionView(appState: appState, isPresented: $appState.showingWindowPreviewPermission)
        }
        .sheet(isPresented: $appState.showingUpdateWindowSheet) {
            UpdateWindowView(appState: appState, isPresented: $appState.showingUpdateWindowSheet)
        }
        .sheet(isPresented: $appState.showingKeyboardShortcutsSheet) {
            KeyboardShortcutsView(appState: appState)
        }
        .onAppear {
            appState.refreshAll()
            // A window reopened straight into full screen never sends "will enter full screen".
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let w = NSApp.windows.first(where: { $0.toolbar?.identifier == "WispTileMainWindow" }),
                   w.styleMask.contains(.fullScreen) {
                    w.toolbar?.isVisible = false
                    isFullScreen = true
                }
            }
        }
        .mainWindowChrome()
    }
}
