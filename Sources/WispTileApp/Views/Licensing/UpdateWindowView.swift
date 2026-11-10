import SwiftUI
import WispTileCore

public struct UpdateWindowView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var isInstalling: Bool = false
    @State private var installProgress: Double = 0.0
    
    public init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Window Header
            ZStack {
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: 0xFF5F57)).frame(width: 12, height: 12)
                            .onTapGesture { isPresented = false }
                        Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 12, height: 12)
                        Circle().fill(Color(hex: 0x28C840)).frame(width: 12, height: 12)
                    }
                    Spacer()
                }
                .padding(.leading, 18)
                
                Text("Software Update")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
            }
            .frame(height: 52)
            .background(Color(hex: 0xF5F5F7))
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Body Content
            VStack(spacing: 18) {
                // Version Header
                HStack(spacing: 16) {
                    WispLogoView(size: 64, cornerRadius: 15)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WispTile 1.4 is ready")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(WispColors.textPrimary)
                        Text("You have \(appState.updateManager.currentVersion) · Released 4 November 2026 · 18.4 MB")
                            .font(.system(size: 13))
                            .foregroundColor(WispColors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                // Release Notes Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("What’s New")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            // NEW
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NEW")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundColor(Color(hex: 0x4A2FC4))
                                
                                noteBullet("Custom tiling templates: draw your own zones and save them.")
                                noteBullet("Create a project from your open windows in one click from the menu bar.")
                            }
                            
                            // IMPROVED
                            VStack(alignment: .leading, spacing: 8) {
                                Text("IMPROVED")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundColor(Color(hex: 0x1F7A3D))
                                
                                noteBullet("Workspace drift is detected faster after a display is connected.")
                                noteBullet("Restore reports now explain why a step failed.")
                            }
                            
                            // FIXED
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FIXED")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundColor(Color(hex: 0x8A4B05))
                                
                                noteBullet("Chrome tabs sometimes opened in the wrong profile.")
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
                
                // Toggle
                HStack(spacing: 10) {
                    WispSwitch(isOn: $appState.settings.automaticallyInstallUpdates, label: "Install future updates automatically", compact: true)
                    Text("Install future updates automatically")
                        .font(.system(size: 13))
                        .foregroundColor(WispColors.textPrimary)
                    Spacer()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            
            // Footer Action Bar
            HStack {
                Button("Skip This Version") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WispColors.textSecondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Remind Me Later") {
                        isPresented = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WispColors.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 30)
                    .background(Color.white)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
                    
                    Button(action: {
                        installUpdate()
                    }) {
                        HStack(spacing: 6) {
                            if isInstalling {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isInstalling ? "Updating…" : "Install and Relaunch")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 30)
                        .background(WispColors.accent)
                        .cornerRadius(7)
                        .shadow(color: Color.black.opacity(0.2), radius: 1, y: 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInstalling)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .frame(width: 720, height: 560)
        .background(Color(hex: 0xF5F5F7))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.16), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func noteBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: 0x6E6E73))
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundColor(WispColors.textPrimary)
        }
    }
    
    private func installUpdate() {
        isInstalling = true
        Task {
            try? await appState.installAndRelaunch()
            isInstalling = false
            isPresented = false
        }
    }
}
