import SwiftUI
import AppKit

@main
struct WispTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    init() {
        if ProcessInfo.processInfo.environment["WISPTILE_SHOW_ONBOARDING"] == "1" {
            AppState.shared.isOnboardingComplete = false
            AppState.shared.showingWelcomeOnboarding = true
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !appState.isOnboardingComplete {
                OnboardingFlowView(appState: appState)
            } else {
                MainContainerView(appState: appState)
                    .frame(minWidth: 820, idealWidth: 1280, maxWidth: .infinity, minHeight: 560, idealHeight: 800, maxHeight: .infinity)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Capture Current Desktop…") {
                    appState.showingCaptureSheet = true
                }
                .keyboardShortcut("c", modifiers: [.control, .option])
                
                Button("Quick Switcher…") {
                    appState.showingQuickSwitcher = true
                }
                .keyboardShortcut(.space, modifiers: [.control, .option])
            }
            
            CommandGroup(after: .windowSize) {
                Button("Tile: Main + Stack") {
                    _ = appState.tileOpenWindows(presetName: "Main + Stack")
                }
                .keyboardShortcut("m", modifiers: [.control, .option])
                
                Button("Tile: Halves") {
                    _ = appState.tileOpenWindows(presetName: "Halves")
                }
                .keyboardShortcut("h", modifiers: [.control, .option])
                
                Button("Tile: Thirds") {
                    _ = appState.tileOpenWindows(presetName: "Thirds")
                }
                .keyboardShortcut("t", modifiers: [.control, .option])
                
                Button("Tile: Maximize") {
                    appState.tileActiveWindow(command: .maximize)
                }
                .keyboardShortcut(.return, modifiers: [.control, .option])
                
                Divider()
                
                Button("Undo Last Tile / Restore") {
                    appState.undoRestore()
                }
                .keyboardShortcut("z", modifiers: [.control, .option])
            }
        }
    }
}

private struct OnboardingFlowView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if appState.showingWelcomeOnboarding {
                WelcomeView(appState: appState, isPresented: $appState.showingWelcomeOnboarding)
            } else if appState.showingPermissionGuide {
                PermissionGuideView(appState: appState, isPresented: $appState.showingPermissionGuide)
            } else if appState.showingWindowPreviewPermission {
                WindowPreviewPermissionView(appState: appState, isPresented: $appState.showingWindowPreviewPermission)
            } else {
                WelcomeView(appState: appState, isPresented: $appState.showingWelcomeOnboarding)
            }
        }
    }
}
