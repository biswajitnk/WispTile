import SwiftUI
import WispTileCore

public struct PermissionGuideView: View {
    @ObservedObject var appState: AppState; @Binding var isPresented: Bool
    @State private var permissionGranted = false
    public init(appState: AppState, isPresented: Binding<Bool>) { self.appState = appState; self._isPresented = isPresented }
    public var body: some View {
        PermissionOnboardingLayout(title: "Allow window control", detail: "macOS asks you to approve any app that moves other apps’ windows. WispTile needs this to tile and restore them.", settingsPath: "Privacy & Security › Accessibility", status: permissionGranted ? "Permission granted. You can continue." : "Waiting for permission. This window updates by itself.", statusGranted: permissionGranted, stepLabel: "2 of 4", secondaryTitle: "Back", uses: ["Move and resize windows", "Read window titles to match them to a project"], avoids: ["Read what is inside your windows", "Record your keystrokes. Previews are optional.", "Send your projects anywhere"], step: 1, secondaryAction: { isPresented = false; appState.showingWelcomeOnboarding = true }, primaryAction: primaryAction)
            .onReceive(Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()) { _ in
                guard !permissionGranted, WindowManager.shared.isAccessibilityGranted() else { return }
                permissionGranted = true
                appState.isAccessibilityGranted = true
            }
    }

    private func primaryAction() {
        if permissionGranted { isPresented = false; appState.showingWindowPreviewPermission = true }
        else { _ = WindowManager.shared.isAccessibilityGranted(promptIfNot: true) }
    }
}
