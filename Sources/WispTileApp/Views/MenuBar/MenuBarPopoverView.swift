import SwiftUI
import AppKit
import WispTileCore

/// Board 18 · Menu bar popover: current project, project switcher, one-click project from open windows.
public struct MenuBarPopoverView: View {
    @ObservedObject var appState: AppState
    @State private var newName = "Untitled Project"
    @State private var looseWindows: [CapturedWindow] = []
    @State private var created: String?
    @State private var offDesktop = 0
    @AppStorage("WispTile.notchTipDismissed") private var notchTipDismissed = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let active = appState.selectedProject ?? appState.projects.first {
                currentProject(active)
                divider
            }
            switchList
            divider.padding(.top, 2)
            notInProjectCard
                .padding(.horizontal, 12)
                .padding(.top, 12)
            if appState.displays.contains(where: { $0.hasNotch }) && !notchTipDismissed {
                notchTip
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            }
            footer.padding(.top, 12)
        }
        .frame(width: 380)
        .background(Color(hex: 0xF6F6F8))
        .onAppear(perform: scanLooseWindows)
        // The popover keeps its view between openings, so rescan every time it is shown.
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.willShowNotification)) { _ in scanLooseWindows() }
    }

    private var divider: some View {
        Rectangle().fill(Color.black.opacity(0.09)).frame(height: 1).padding(.horizontal, 12)
    }

    // MARK: Current project
    @ViewBuilder
    private func currentProject(_ p: Project) -> some View {
        let drift = appState.isAccessibilityGranted ? DriftEngine.shared.detectDrift(for: p) : nil
        let drifted = drift?.driftedWindows.count ?? 0
        let warn = drift == nil || drifted > 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(String(p.name.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: p.colorHex))
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    if drift == nil {
                        // Without Accessibility access nothing can be moved: make the fix one click away.
                        Button(action: requestAccessibility) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: 0xE08A00)).frame(width: 7, height: 7)
                                Text("Accessibility access needed ·")
                                Text("Allow…").underline()
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: 0x8A4B05))
                        }
                        .buttonStyle(.plain)
                        .help("Opens System Settings › Privacy & Security › Accessibility")
                    } else {
                        HStack(spacing: 6) {
                            Circle().fill(warn ? Color(hex: 0xE08A00) : Color(hex: 0x30B552)).frame(width: 7, height: 7)
                            Text(drifted > 0 ? "\(drifted) window\(drifted == 1 ? "" : "s") drifted" : "All windows in place")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(warn ? Color(hex: 0x8A4B05) : Color(hex: 0x1F7A3D))
                    }
                }
                Spacer(minLength: 0)
            }

            ZStack(alignment: .bottomLeading) {
                LayoutCanvasView(items: LayoutPreviewStore.canvasItems(for: mainDisplayOnly(p), layout: p.layouts.values.first), gap: 2, compact: true, fills: true)
                Text("Saved layout · \(p.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color(hex: 0x141418).opacity(0.78))
                    .cornerRadius(5)
                    .padding(6)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.3), lineWidth: 0.5))

            HStack(spacing: 8) {
                Button {
                    if drifted > 0 {
                        appState.selectedProject = p
                        appState.selectedNav = .repair
                        openMainWindow()
                    } else {
                        Task { await appState.executeRestore(for: p) }
                    }
                } label: {
                    Text(drifted > 0 ? "Repair Workspace" : "Restore Workspace")
                }
                .buttonStyle(WispToolbarPrimaryStyle(fullWidth: true))
                Button("Preview…") {
                    appState.triggerRestorePreview(for: p)
                    openMainWindow()
                }
                .buttonStyle(WispToolbarSecondaryStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    /// The preview shows the main display only, so windows saved on other screens don't pile on top.
    private func mainDisplayOnly(_ p: Project) -> Project {
        var copy = p
        copy.items = p.items.filter { $0.displayIndex == 0 }
        return copy
    }

    // MARK: Switch project
    private var switchList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Switch Project").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("Screens").font(.system(size: 11))
            }
            .foregroundColor(Color(hex: 0x6E6E73))
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 6)

            if appState.projects.isEmpty {
                Text("No projects yet. Create one from your open windows below.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
            }
            ForEach(appState.projects) { project in
                projectRow(project)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func projectRow(_ project: Project) -> some View {
        let isCurrent = project.id == (appState.selectedProject ?? appState.projects.first)?.id
        let screens = max(1, project.layouts.values.map { $0.displaySignature.screenCount }.max() ?? 1)
        return Button {
            appState.selectProject(project)
            Task { await appState.executeRestore(for: project) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: 0x5B3CE0))
                    .frame(width: 14)
                    .opacity(isCurrent ? 1 : 0)
                Text(String(project.name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color(hex: project.colorHex))
                    .cornerRadius(6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                        .foregroundColor(WispColors.textPrimary)
                        .lineLimit(1)
                    Text("\(project.items.count) app\(project.items.count == 1 ? "" : "s") · \(screens) display\(screens == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x6E6E73))
                }
                Spacer(minLength: 8)
                screensGlyph(count: screens, highlighted: isCurrent)
                Text(appState.displayShortcut(for: project) ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .frame(minWidth: 24, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(isCurrent ? Color.black.opacity(0.06) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Restore project \(project.name), \(project.items.count) apps, \(screens) displays")
    }

    /// Overlapping-rectangle glyph showing how many screens a project's layout spans.
    private func screensGlyph(count: Int, highlighted: Bool) -> some View {
        let n = min(max(count, 1), 3)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<n, id: \.self) { i in
                let last = i == n - 1
                RoundedRectangle(cornerRadius: 3)
                    .fill(highlighted && last ? Color(hex: 0xE6E0FD) : (last ? Color(hex: 0xECECEF) : Color(hex: 0xF6F6F8)))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(highlighted && last ? Color(hex: 0x5B3CE0) : (last ? Color(hex: 0x6E6E73) : Color(hex: 0x9A9AA0)), lineWidth: 1.5))
                    .frame(width: n == 1 ? 22 : 20, height: n == 1 ? 15 : 13)
                    .offset(x: n == 1 ? 6 : CGFloat(i) * (n == 2 ? 10 : 6), y: n == 1 ? 4 : CGFloat(i) * (n == 2 ? 7 : 4.5))
            }
        }
        .frame(width: 34, height: 24, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    // MARK: Not in a project
    private var notInProjectCard: some View {
        let names = uniqueApps(looseWindows)
        let displays = Set(looseWindows.map(\.displayIndex)).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Not in a project").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(looseWindows.count) on this desktop")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
            }
            if offDesktop > 0 {
                Text("+\(offDesktop) more window\(offDesktop == 1 ? "" : "s") on other desktops, in full screen or minimized. Switch to that desktop to include them.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if names.isEmpty {
                Text(created ?? "Every open window already belongs to a project.")
                    .font(.system(size: 12))
                    .foregroundColor(created == nil ? Color(hex: 0x3A3A3C) : Color(hex: 0x1F7A3D))
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: -9) {
                        ForEach(Array(names.prefix(4).enumerated()), id: \.offset) { _, a in
                            AppIconView(bundleId: a.bundleId, appName: a.name, size: 24)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                        if names.count > 4 {
                            Text("+\(names.count - 4)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: 0x3A3A3C))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(hex: 0xE5E5EA)))
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                    Text(summary(names.map(\.name), displays: displays))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x3A3A3C))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    TextField("Project name", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.white)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
                        .accessibilityLabel("New project name")
                    Button("Create Project", action: createFromLoose)
                        .buttonStyle(WispToolbarPrimaryStyle())
                }
                Text("Saves the apps, folders, tabs, window positions and display setup as they are now.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .wispPanel()
    }

    private func uniqueApps(_ windows: [CapturedWindow]) -> [(name: String, bundleId: String)] {
        var seen = Set<String>()
        return windows.compactMap { w in seen.insert(w.appName).inserted ? (w.appName, w.bundleId) : nil }
    }

    private func summary(_ names: [String], displays: Int) -> String {
        let shown = names.prefix(3).joined(separator: ", ")
        let more = names.count > 3 ? " and \(names.count - 3) more" : ""
        return "\(shown)\(more) on \(max(1, displays)) display\(displays == 1 ? "" : "s")"
    }

    // MARK: Notch tip
    private var notchTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: 0x8A4B05))
            (Text("On a MacBook with a notch, a crowded menu bar can hide this icon. Open from the Dock or press ")
             + Text(appState.settings.quickSwitcherShortcut).font(.system(size: 12, design: .monospaced))
             + Text("."))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x5C3303))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Got It") { notchTipDismissed = true }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x5C3303))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Color(hex: 0x8A4B05).opacity(0.14))
                .cornerRadius(6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: 0xFFF4E0))
        .cornerRadius(10)
    }

    // MARK: Footer
    private var footer: some View {
        VStack(spacing: 0) {
            footerRow("Open WispTile…", keys: "⌘O", action: openMainWindow)
                .keyboardShortcut("o", modifiers: .command)
            footerRow(appState.isAutomationPaused ? "Resume Automation" : "Pause Automation for 1 Hour") {
                appState.isAutomationPaused.toggle()
            }
            if appState.updateManager.availableUpdate != nil {
                footerRow("Update Available…", tint: Color(hex: 0x4A2FC4)) {
                    appState.showingUpdateWindowSheet = true
                    openMainWindow()
                }
            }
            footerRow("Quit WispTile", keys: "⌘Q") { NSApplication.shared.terminate(nil) }
        }
        .padding(8)
        .overlay(Rectangle().fill(Color.black.opacity(0.09)).frame(height: 1), alignment: .top)
    }

    private func footerRow(_ title: String, keys: String? = nil, tint: Color = WispColors.textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 13)).foregroundColor(tint)
                Spacer()
                if let keys {
                    Text(keys).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: 0x6E6E73))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
    }

    // MARK: Actions
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            w.makeKeyAndOrderFront(nil)
        }
    }

    private func requestAccessibility() {
        _ = WindowManager.shared.isAccessibilityGranted(promptIfNot: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func scanLooseWindows() {
        offDesktop = WindowManager.shared.countWindowsOffCurrentDesktop()
        appState.isAccessibilityGranted = WindowManager.shared.isAccessibilityGranted()
        let inProjects = Set(appState.projects.flatMap { $0.items.map(\.bundleId) })
        let own = Bundle.main.bundleIdentifier ?? "com.wisptile.WispTile"
        looseWindows = CaptureEngine.shared.scanDesktop().windows.filter {
            !$0.isCallApp && $0.bundleId != own && !inProjects.contains($0.bundleId)
        }
    }

    private func createFromLoose() {
        let name = newName.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Project" : newName
        let project = CaptureEngine.shared.captureProject(name: name, selectedWindows: looseWindows)
        appState.saveProject(project)
        created = "Created “\(name)” from \(looseWindows.count) window\(looseWindows.count == 1 ? "" : "s")."
        newName = "Untitled Project"
        scanLooseWindows()
    }
}

/// Row highlight on hover/press for menu-style rows.
struct MenuRowButtonStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x5B3CE0).opacity(configuration.isPressed ? 0.16 : (hover ? 0.09 : 0))))
            .onHover { hover = $0 }
    }
}
