import SwiftUI

public struct WindowPreviewPermissionView: View {
    @ObservedObject var appState: AppState; @Binding var isPresented: Bool
    @State private var permissionGranted = false
    public init(appState: AppState, isPresented: Binding<Bool>) { self.appState = appState; self._isPresented = isPresented }
    public var body: some View {
        PermissionOnboardingLayout(title: "Show real window previews", detail: "Allow WispTile to save a small picture of each window for project lists, the switcher, and restore previews.", settingsPath: "Privacy & Security › Screen & System Audio Recording", status: permissionGranted ? "Permission granted. You can continue." : "Waiting for permission. This window updates by itself.", statusGranted: permissionGranted, stepLabel: "3 of 4", secondaryTitle: "Back", uses: ["Take one picture of each window when you capture or restore a project", "Show it in the project list, switcher and restore preview"], avoids: ["Send pictures anywhere. They stay on this Mac.", "Record video, audio or keystrokes", "Capture while you are in a call or a password field"], step: 2, secondaryAction: goBack, primaryAction: primaryAction)
            .onReceive(Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()) { _ in
                guard !permissionGranted, WindowShots.hasAccess else { return }
                permissionGranted = true
            }
    }
    private func primaryAction() { if permissionGranted { finishStep() } else { WindowShots.requestAccess() } }
    private func goBack() { isPresented = false; appState.showingPermissionGuide = true }
    private func finishStep() { isPresented = false; appState.completeOnboarding() }
}

public struct PermissionOnboardingLayout: View {
    let title: String, detail: String, settingsPath: String, status: String
    let statusGranted: Bool
    let stepLabel: String, secondaryTitle: String
    let uses: [String], avoids: [String], step: Int, secondaryAction: () -> Void, primaryAction: () -> Void
    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 22, weight: .bold)).foregroundColor(WispColors.textPrimary)
                    Text(detail).font(.system(size: 13)).foregroundColor(WispColors.textSecondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.top, 7)
                    infoCard("WHAT IT USES THIS FOR", color: WispColors.success, icon: "checkmark.circle.fill", items: uses).padding(.top, 20)
                    infoCard("WHAT IT DOES NOT DO", color: WispColors.error, icon: "xmark.circle.fill", items: avoids).padding(.top, 10)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 9) {
                    Text("In System Settings, turn this on").font(.system(size: 12, weight: .semibold))
                    settingsMock
                    HStack(alignment: .top, spacing: 7) { if statusGranted { Image(systemName: "checkmark.circle.fill").foregroundColor(WispColors.success) } else { ProgressView().controlSize(.small) }; Text(status).font(.system(size: 11)).foregroundColor(statusGranted ? WispColors.success : WispColors.textSecondary).fixedSize(horizontal: false, vertical: true) }.padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 36).padding(.top, 20)
            Spacer()
            OnboardingFooter(step: step, label: stepLabel) { Button(secondaryTitle, action: secondaryAction).buttonStyle(WispSecondaryButtonStyle()) } trailing: { Button(statusGranted ? "Continue" : "Open System Settings", action: primaryAction).buttonStyle(OnboardingPrimaryButtonStyle()) }
        }.frame(width: 720, height: 560).background(WispColors.canvas).onboardingWindowChrome(width: 720, height: 560)
    }
    private func infoCard(_ heading: String, color: Color, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(heading).font(.system(size: 10, weight: .bold)).foregroundColor(color); ForEach(items, id: \.self) { item in HStack(alignment: .top, spacing: 8) { Image(systemName: icon).font(.system(size: 12)).foregroundColor(color); Text(item).font(.system(size: 11)).foregroundColor(WispColors.textPrimary).fixedSize(horizontal: false, vertical: true) } } }.padding(.vertical, 14).padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(WispColors.border))
    }
    private var settingsMock: some View {
        VStack(spacing: 0) {
            HStack { Circle().fill(Color.red.opacity(0.8)).frame(width: 7, height: 7); Circle().fill(Color.yellow.opacity(0.9)).frame(width: 7, height: 7); Circle().fill(Color.green.opacity(0.8)).frame(width: 7, height: 7); Spacer(); Text("Privacy & Security").font(.system(size: 10, weight: .semibold)); Spacer() }.padding(.horizontal, 10).frame(height: 30).background(Color.black.opacity(0.035))
            Text(settingsPath).font(.system(size: 9, weight: .medium)).foregroundColor(WispColors.textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(10)
            settingRow("Finder", on: false); settingRow("WispTile", on: true).background(Color(hex: 0x5B3CE0).opacity(0.08)); settingRow("Terminal", on: false)
            HStack(spacing: 5) { Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold)); Text("Switch on WispTile").font(.system(size: 10, weight: .semibold)) }.foregroundColor(Color(hex: 0x5B3CE0)).padding(.vertical, 12)
        }.background(Color.white).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(WispColors.border)).shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
    private func settingRow(_ name: String, on: Bool) -> some View {
        HStack { Group { if name == "WispTile" { WispLogoView(size: 20, cornerRadius: 4) } else { RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 20, height: 20) } }; Text(name).font(.system(size: 10)); Spacer(); Capsule().fill(on ? Color.green : Color.gray.opacity(0.25)).frame(width: 28, height: 16).overlay(Circle().fill(.white).frame(width: 12, height: 12).offset(x: on ? 6 : -6)) }.padding(.horizontal, 12).frame(height: 34)
    }
}
