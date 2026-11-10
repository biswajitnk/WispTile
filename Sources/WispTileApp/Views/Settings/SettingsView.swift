import SwiftUI
import WispTileCore

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    
    @State private var showingExportAlert: Bool = false
    @State private var exportPath: String = ""
    @State private var showingDiagnosticsSheet: Bool = false
    @AppStorage("WispTile.lastUpdateCheck") private var lastUpdateCheck: Double = 0
    @State private var checking = false
    private var selectedTab: Binding<Int> { $appState.settingsTab }
    
    public init(appState: AppState, initialTab: Int? = nil) {
        self.appState = appState
        if let t = initialTab { appState.settingsTab = t }
    }
    
    /// Width of the settings content; License and Updates use one half-width column only when there is room.
    @State private var contentWidth: CGFloat = 1028
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Group {
                switch appState.settingsTab {
                case 1:
                    KeyboardShortcutsView(appState: appState)
                case 2:
                    updatesTab
                default:
                    ScrollView {
                        AdaptiveStack(breakpoint: 780, spacing: 20) {
                            VStack(spacing: 18) {
                                profileCard
                                generalCard
                            }
                            .frame(maxWidth: .infinity)

                            VStack(spacing: 18) {
                                notificationsCard
                                privacyCard
                                aboutCard
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(24)
                    }
                }
            }
        }
        .background(Color(hex: 0xF5F5F7))
        .background(GeometryReader { g in
            Color.clear
                .onAppear { contentWidth = g.size.width }
                .onChange(of: g.size.width) { contentWidth = $0 }
        })
        .alert("Export Successful", isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Projects and templates exported to:\n\(exportPath)")
        }
        .sheet(isPresented: $showingDiagnosticsSheet) {
            DiagnosticsExportSheet()
        }
    }
    
    @ViewBuilder
    private var headerBar: some View {
        HStack {
            WispSegmented(
                selection: selectedTab,
                options: ["General", "Shortcuts", "Updates"],
                horizontalPadding: 16
            )
            .fixedSize()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var pendingUpdate: UpdateInfo? { appState.backgroundUpdateInfo ?? appState.updateManager.availableUpdate }
    
    /// Board 22 · Updates tab.
    private var updatesTab: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    section("Updates") {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Version \(appState.updateManager.currentVersion)").font(.system(size: 13, weight: .semibold))
                                    Text(updateStatusLine)
                                        .font(.system(size: 12, weight: pendingUpdate == nil ? .regular : .medium))
                                        .foregroundColor(pendingUpdate == nil ? Color(hex: 0x6E6E73) : Color(hex: 0x4A2FC4))
                                }
                                Spacer()
                                if pendingUpdate != nil {
                                    Button("Install Update…") { appState.showingUpdateWindowSheet = true }
                                        .buttonStyle(WispSmallPrimaryStyle())
                                } else {
                                    Button(checking ? "Checking…" : "Check Now") { checkNow() }
                                        .buttonStyle(WispSmallButtonStyle())
                                        .disabled(checking)
                                }
                            }
                            .frame(height: 56)
                            switchRow("Check for updates automatically", $appState.settings.automaticallyCheckForUpdates)
                            switchRow("Show a notification when WispTile is closed", $appState.settings.notifyWhenAppIsClosed)
                            switchRow("Install updates automatically", $appState.settings.automaticallyInstallUpdates)
                        }
                        .padding(.horizontal, 16)
                        .wispPanel()
                    }
                    if let u = pendingUpdate {
                        section("What’s New in \(u.version)") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(u.releaseNotes.prefix(3), id: \.id) { n in
                                    Text(n.text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                                }
                                Button("View Full Release Notes") { appState.showingUpdateWindowSheet = true }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: 0x4A2FC4))
                                    .padding(.top, 4)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .wispPanel()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                if contentWidth >= 900 { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    private var updateStatusLine: String {
        let checked = lastUpdateCheck > 0
            ? " · last checked " + Date(timeIntervalSince1970: lastUpdateCheck).formatted(.relative(presentation: .named))
            : ""
        if let u = pendingUpdate { return "\(u.version) is available\(checked)" }
        return "You’re up to date\(checked)"
    }
    
    private func checkNow() {
        checking = true
        Task {
            await appState.checkForUpdates()
            lastUpdateCheck = Date().timeIntervalSince1970
            checking = false
        }
    }
    
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0x6E6E73)).padding(.horizontal, 4)
            content()
        }
    }
    
    private func divRow<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 10) { content() }
            .frame(height: 46)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
    
    private func switchRow(_ title: String, _ value: Binding<Bool>) -> some View {
        divRow {
            Text(title).font(.system(size: 13))
            Spacer()
            WispSwitch(isOn: value, label: title, compact: true)
        }
    }

    private func settingsRow<Accessory: View>(_ title: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            accessory()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }

    private func toggleRow(_ title: String, value: Binding<Bool>) -> some View {
        settingsRow(title) {
            Toggle("", isOn: value).labelsHidden().toggleStyle(SwitchToggleStyle(tint: WispColors.success))
        }
    }
    
    @ViewBuilder
    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x7B79F7), Color(hex: 0x4B49D6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                
                Text(String(appState.settings.userName.prefix(1)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.settings.userName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
                if !appState.settings.userEmail.isEmpty {
                    Text(appState.settings.userEmail)
                        .font(.system(size: 12))
                        .foregroundColor(WispColors.textSecondary)
                }
                Text("Free and open source · MIT License")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: 0x1F7A3D))
            }
            
            Spacer()
            
            Button("GitHub…") {
                NSWorkspace.shared.open(AppLinks.repository)
            }
            .help("Source code, issues and releases")
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(WispColors.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.white)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 1, y: 0.5)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
    }
    
    @ViewBuilder
    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WispColors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Open at login")
                        .font(.system(size: 13))
                    Spacer()
                    WispSwitch(isOn: $appState.settings.launchAtLogin, label: "Open at login", compact: true)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show in menu bar")
                            .font(.system(size: 13))
                        Text("Icon hidden on a MacBook with a notch? Turn on Show in Dock.")
                            .font(.system(size: 12))
                            .foregroundColor(WispColors.textSecondary)
                    }
                    Spacer()
                    WispSwitch(isOn: $appState.settings.showInMenuBar, label: "Show in menu bar", compact: true)
                }
                .frame(minHeight: 56)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Show in Dock")
                        .font(.system(size: 13))
                    Spacer()
                    WispSwitch(isOn: $appState.settings.showInDock, label: "Show in Dock", compact: true)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Keyboard shortcuts")
                        .font(.system(size: 13))
                    Spacer()
                    Button("Customize…") {
                        appState.settingsTab = 1
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WispColors.accent)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Appearance")
                        .font(.system(size: 13))
                    Spacer()
                    HStack(spacing: 0) {
                        appearanceSegment("Light")
                        appearanceSegment("Dark")
                        appearanceSegment("Auto")
                    }
                    .padding(2)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(8)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
        }
    }
    
    @ViewBuilder
    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WispColors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Restore results")
                        .font(.system(size: 13))
                    Spacer()
                    WispSwitch(isOn: $appState.settings.notifyOnRestoreResults, label: "Restore results", compact: true)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Workspace drift alerts")
                        .font(.system(size: 13))
                    Spacer()
                    WispSwitch(isOn: $appState.settings.notifyOnDriftAlerts, label: "Workspace drift alerts", compact: true)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("App updates")
                        .font(.system(size: 13))
                    Spacer()
                    Button("Open Update Settings") {
                        appState.settingsTab = 2
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WispColors.accent)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
        }
    }
    
    @ViewBuilder
    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy and Data")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WispColors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Share anonymous usage data")
                            .font(.system(size: 13))
                        Text("Never includes window titles or file paths")
                            .font(.system(size: 12))
                            .foregroundColor(WispColors.textSecondary)
                    }
                    Spacer()
                    WispSwitch(isOn: $appState.settings.shareAnonymousUsageData, label: "Share anonymous usage data", compact: true)
                }
                .frame(minHeight: 52)
                .padding(.horizontal, 16)

                Divider().background(Color.black.opacity(0.07))

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show real window previews")
                            .font(.system(size: 13))
                        Text("Needs Screen Recording. Pictures stay on this Mac.")
                            .font(.system(size: 12))
                            .foregroundColor(WispColors.textSecondary)
                    }
                    Spacer()
                    WispSwitch(isOn: Binding(
                        get: { WindowShots.hasAccess },
                        set: { _ in
                            // macOS owns this permission: turning it on asks for access, turning it off opens System Settings.
                            if WindowShots.hasAccess,
                               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                NSWorkspace.shared.open(url)
                            } else {
                                WindowShots.requestAccess()
                            }
                        }
                    ), label: "Show real window previews", compact: true)
                }
                .frame(minHeight: 56)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Export projects and templates")
                        .font(.system(size: 13))
                    Spacer()
                    Button("Export…") {
                        if let url = try? appState.exportProjectsAndTemplates() {
                            exportPath = url.path
                            showingExportAlert = true
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 0.5, y: 0.5)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Send diagnostics to support")
                        .font(.system(size: 13))
                    Spacer()
                    Button("Send…") {
                        showingDiagnosticsSheet = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 0.5, y: 0.5)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
        }
    }
    
    @ViewBuilder
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WispColors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(.system(size: 13))
                    Spacer()
                    Text(appState.updateManager.currentVersion)
                        .font(.system(size: 13))
                        .foregroundColor(WispColors.textSecondary)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
                
                Divider().background(Color.black.opacity(0.07))
                
                HStack {
                    Text("Help and support")
                        .font(.system(size: 13))
                    Spacer()
                    Button("Open") {
                        NSWorkspace.shared.open(AppLinks.issues)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WispColors.accent)
                }
                .frame(height: 46)
                .padding(.horizontal, 16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
        }
    }
    
    @ViewBuilder
    private func appearanceSegment(_ mode: String) -> some View {
        Button(action: {
            appState.settings.appearance = mode
        }) {
            Text(mode)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(appState.settings.appearance == mode ? WispColors.textPrimary : Color(hex: 0x3A3A3C))
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(appState.settings.appearance == mode ? Color.white : Color.clear)
                .cornerRadius(6)
                .shadow(color: appState.settings.appearance == mode ? Color.black.opacity(0.18) : Color.clear, radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
    }
}
