import SwiftUI
import AppKit
import WispTileCore

public struct ProjectsDetailView: View {
    @ObservedObject var appState: AppState
    @State private var activeDisplayMode: String = "At Desk"
    @State private var liveItems: [CanvasItem] = []
    @State private var liveShots: [CGWindowID: NSImage] = [:]
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        if appState.projects.isEmpty {
            EmptyStateView(appState: appState)
        } else if let project = appState.selectedProject ?? appState.projects.first {
            VStack(spacing: 0) {
                toolbar(for: project)
                if !appState.isAccessibilityGranted {
                    AccessibilityBanner().padding(.horizontal, 24).padding(.top, 12)
                }
                projectSwitcher(selected: project)
                GeometryReader { geo in
                    let contentW = geo.size.width - 48
                    if contentW >= 760 && geo.size.height >= 500 {
                        // Board 5: the two cards fill the window, safety switches pinned below.
                        VStack(spacing: 16) {
                            HStack(alignment: .top, spacing: 16) {
                                layoutCard(for: project).frame(width: (contentW - 16) * 1.3 / 2.3)
                                restoresCard(for: project).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(maxHeight: .infinity)
                            safetyBar(for: project, stacked: false)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                layoutCard(for: project).frame(height: 360)
                                restoresCard(for: project)
                                safetyBar(for: project, stacked: contentW < 760)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .background(Color(hex: 0xF5F5F7))
        } else {
            EmptyStateView(appState: appState)
        }
    }
    
    // MARK: - Project switcher (Board 5)
    private func projectSwitcher(selected: Project) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.projects) { p in
                    let isSel = p.id == selected.id
                    Button { appState.selectProject(p) } label: {
                        HStack(spacing: 8) {
                            Text(String(p.name.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color(hex: p.colorHex))
                                .cornerRadius(5)
                            Text(p.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(WispColors.textPrimary)
                                .lineLimit(1)
                            if let sc = appState.displayShortcut(for: p) {
                                Text(sc)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: 0x6E6E73))
                            }
                        }
                        .padding(.leading, 8).padding(.trailing, 12)
                        .frame(height: 30)
                        .background(isSel ? Color.white : Color.clear)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color(hex: 0x5B3CE0).opacity(0.55) : Color.black.opacity(0.12), lineWidth: 1))
                        .shadow(color: isSel ? Color.black.opacity(0.08) : .clear, radius: 0.5, y: 0.5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show project \(p.name)")
                }
                Button("+ Capture") { appState.showingCaptureSheet = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: 0x4A2FC4))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 1)
        }
        .padding(.top, 12)
    }
    
    // MARK: - Toolbar (Board 1)
    @ViewBuilder
    private func toolbar(for project: Project) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                let realPath = project.items.compactMap({ $0.pathOrURL }).first(where: { $0.hasPrefix("/") || $0.hasPrefix("~") })
                Text(realPath.map { ($0 as NSString).abbreviatingWithTildeInPath }
                     ?? "\(project.items.count) app\(project.items.count == 1 ? "" : "s") · \(project.layouts.count) layout\(project.layouts.count == 1 ? "" : "s")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(-1)
            
            Spacer(minLength: 12)
            
            HStack(spacing: 8) {
                Button("Edit…") {
                    appState.showingEditProjectSheet = true
                }
                .buttonStyle(WispToolbarSecondaryStyle())
                
                Button("Preview…") {
                    appState.triggerRestorePreview(for: project)
                }
                .buttonStyle(WispToolbarSecondaryStyle())
                
                Button(action: {
                    Task {
                        await appState.executeRestore(for: project)
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Restore")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        
                        if let shortcut = appState.displayShortcut(for: project) {
                            Text(shortcut)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.22))
                                .cornerRadius(5)
                        }
                    }
                    .fixedSize()
                    .padding(.leading, 14)
                    .padding(.trailing, 6)
                    .frame(height: 30)
                    .background(Color(hex: 0x5B3CE0))
                    .cornerRadius(7)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, y: 0.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restore \(project.name)")
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
        .frame(height: 52)
        .background(Color(hex: 0xF5F5F7))
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }
    
    // MARK: - Layout Card (Board 1)
    @ViewBuilder
    private func layoutCard(for project: Project) -> some View {
        let activeLayout: ProjectLayout? = {
            if activeDisplayMode == "At Desk" {
                return project.layouts.values.first(where: { $0.displaySignature.screenCount > 1 }) ?? project.layouts.values.first
            } else {
                return project.layouts.values.first(where: { $0.displaySignature.screenCount == 1 }) ?? project.layouts.values.first
            }
        }()
        
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack {
                Text("Layout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
                layoutPicker(for: project)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button("Snapping") {
                        appState.selectedNav = .snapping
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: 0x4A2FC4))
                    
                    Button("Edit Template") {
                        appState.selectedNav = .templateEditor
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: 0x4A2FC4))
                    
                    // Display Mode Switcher Pill
                    displayModeSwitcher
                }
            }
            
            canvasArea(for: project, layout: activeLayout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LayoutCanvasView.backdrop)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Footnote Row
            HStack {
                let arrangedWith = TemplateEngine.shared.template(id: project.layoutTemplateId)
                let screenInfo = arrangedWith != nil && activeDisplayMode != "Live"
                    ? "Arranged with \(arrangedWith!.name) on restore"
                    : (activeLayout != nil
                       ? "Saved for \(activeLayout!.displaySignature.description)"
                       : (activeDisplayMode == "At Desk" ? "Saved for external display" : "Saved for built-in display"))
                
                Text(screenInfo)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                
                Spacer()
                
                let hasDesk = project.layouts.values.contains { $0.displaySignature.screenCount > 1 }
                let hasLaptop = project.layouts.values.contains { $0.displaySignature.screenCount == 1 }
                Button(activeDisplayMode == "Live" ? "Updating live"
                       : (activeDisplayMode == "At Desk" ? (hasLaptop ? "Laptop layout saved" : "Add a laptop layout")
                          : (hasDesk ? "Desk layout saved" : "Add a desk layout"))) {
                    appState.selectedNav = .displays
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x4A2FC4))
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
    }
    
    /// Pick how this project's windows are arranged on restore, right on the Layout card.
    private func layoutPicker(for project: Project) -> some View {
        let current = TemplateEngine.shared.template(id: project.layoutTemplateId)
        return Menu {
            Button("As captured") { appState.setLayout(nil, for: project) }
            Divider()
            ForEach(appState.allTemplates) { t in
                Button(t.name) { appState.setLayout(t, for: project) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(current?.name ?? "As captured")
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(current == nil ? WispColors.textPrimary : Color(hex: 0x4A2FC4))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(current == nil ? Color.white : Color(hex: 0x5B3CE0).opacity(0.08))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(current == nil ? Color.black.opacity(0.14) : Color(hex: 0x5B3CE0).opacity(0.45), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("How this project's windows are arranged when you restore it")
        .accessibilityLabel("Project layout")
    }
    
    // MARK: - Display Mode Switcher
    @ViewBuilder
    private var displayModeSwitcher: some View {
        HStack(spacing: 0) {
            displayModeButton(title: "At Desk", isSelected: activeDisplayMode == "At Desk")
            displayModeButton(title: "On Laptop", isSelected: activeDisplayMode == "On Laptop")
            displayModeButton(title: "Live", isSelected: activeDisplayMode == "Live")
        }
        .padding(2)
        .background(Color.black.opacity(0.06))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func displayModeButton(title: String, isSelected: Bool) -> some View {
        Button(title) {
            activeDisplayMode = title
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.white : Color.clear)
        .foregroundColor(isSelected ? WispColors.textPrimary : Color(hex: 0x3A3A3C))
        .cornerRadius(6)
        .shadow(color: isSelected ? Color.black.opacity(0.18) : Color.clear, radius: 1, y: 0.5)
    }
    
    // MARK: - Canvas (saved preview image, per-layout render, or live desktop)
    @ViewBuilder
    private func canvasArea(for project: Project, layout: ProjectLayout?) -> some View {
        ZStack(alignment: .topTrailing) {
            if activeDisplayMode == "Live" {
                LayoutCanvasView(items: liveItems, fills: true)
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: 0x28C840)).frame(width: 7, height: 7)
                    Text("Live · \(liveItems.count) window\(liveItems.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.35))
                .cornerRadius(10)
                .padding(10)
            } else {
                // Main display only, so windows saved on another screen don't pile on top.
                LayoutCanvasView(items: LayoutPreviewStore.canvasItems(for: mainDisplayOnly(project), layout: layout), fills: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            if !WindowShots.hasAccess {
                Button(action: { WindowShots.requestAccess() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                        Text("Allow Screen Recording for real window previews")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .onAppear {
            refreshLive()
            if !StorageEngine.shared.hasPreview(for: project.id) { LayoutPreviewStore.save(project: project) }
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            if activeDisplayMode == "Live" { refreshLive() }
        }
    }
    
    private func mainDisplayOnly(_ p: Project) -> Project {
        var copy = p
        copy.items = p.items.filter { $0.displayIndex == 0 }
        return copy
    }
    
    private func refreshLive() {
        let (windows, _) = CaptureEngine.shared.scanDesktop()
        liveItems = windows.map {
            CanvasItem(id: "\($0.id)", appName: $0.appName, bundleId: $0.bundleId, pid: $0.pid,
                       detail: $0.detectedPathOrURL, rect: $0.relativeRect, image: liveShots[$0.id])
        }
        guard activeDisplayMode == "Live", WindowShots.hasAccess else { return }
        let ids = windows.map { $0.id }
        Task {
            let shots = await WindowShots.capture(windowIDs: ids, maxWidth: 480)
            guard !shots.isEmpty else { return }
            liveShots = shots
            liveItems = windows.map {
                CanvasItem(id: "\($0.id)", appName: $0.appName, bundleId: $0.bundleId, pid: $0.pid,
                           detail: $0.detectedPathOrURL, rect: $0.relativeRect, image: shots[$0.id])
            }
        }
    }
    
    // MARK: - What Gets Restored Card (Board 5)
    @ViewBuilder
    private func restoresCard(for project: Project) -> some View {
        let runningApps = NSWorkspace.shared.runningApplications
        VStack(alignment: .leading, spacing: 0) {
            Text("What Gets Restored")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WispColors.textPrimary)
                .padding(.bottom, 8)
            
            if project.items.isEmpty {
                VStack(spacing: 8) {
                    Text("No windows captured yet")
                        .font(.system(size: 13))
                        .foregroundColor(WispColors.textSecondary)
                    Button("+ Capture Open Windows") { appState.showingCaptureSheet = true }
                        .buttonStyle(WispPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(project.items) { item in
                            let status = itemStatus(item, running: runningApps)
                            HStack(spacing: 12) {
                                AppIconView(bundleId: item.bundleId, appName: item.appName, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.appName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(WispColors.textPrimary)
                                    Text(itemDetail(item))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(Color(hex: 0x6E6E73))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 8)
                                Text(status.text)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(status.color)
                                    .fixedSize()
                            }
                            .padding(.vertical, 11)
                            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            Text(restoreNote(for: project))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .wispPanel()
    }
    
    private func itemStatus(_ item: ProjectItem, running: [NSRunningApplication]) -> (text: String, color: Color) {
        if appState.settings.excludedApps.appNames.contains(item.appName) || RulesEngine.shared.isCallApp(bundleId: item.bundleId, appName: item.appName) {
            return ("Needs attention", Color(hex: 0x8A4B05))
        }
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) == nil,
           !running.contains(where: { $0.localizedName == item.appName }) {
            return ("Needs attention", Color(hex: 0x8A4B05))
        }
        let isRunning = running.contains { app in
            (app.bundleIdentifier?.caseInsensitiveCompare(item.bundleId) == .orderedSame) ||
            (app.localizedName?.caseInsensitiveCompare(item.appName) == .orderedSame)
        }
        return isRunning ? ("Running", Color(hex: 0x1F7A3D)) : ("Will launch", Color(hex: 0x4A2FC4))
    }
    
    private func itemDetail(_ item: ProjectItem) -> String {
        guard let p = item.pathOrURL, !p.isEmpty else { return "Window position only" }
        if p.hasPrefix("/") || p.hasPrefix("~") {
            let short = (p as NSString).abbreviatingWithTildeInPath
            return item.appName.lowercased().contains("terminal") ? "cwd \(short)" : "folder \(short)"
        }
        return p.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
    }
    
    private func restoreNote(for project: Project) -> String {
        var parts: [String] = []
        if project.items.contains(where: { $0.appName.lowercased().contains("terminal") && $0.pathOrURL != nil }) {
            parts.append("Terminal opens at the project folder.")
        }
        parts.append(project.restoreOptions.reuseExistingWindows
                     ? "Apps that are already open keep their windows; nothing is closed or duplicated."
                     : "Each app opens a new window for this project.")
        return parts.joined(separator: " ")
    }
    
    private func lastRestoredText(for project: Project) -> String {
        guard let snap = appState.snapshots.filter({ $0.sourceProjectId == project.id }).max(by: { $0.timestamp < $1.timestamp }) else {
            return "Not restored yet"
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return "Last restored \(f.localizedString(for: snap.timestamp, relativeTo: Date()))"
    }
    
    // MARK: - Bottom Safety Bar (Board 5)
    @ViewBuilder
    private func safetyBar(for project: Project, stacked: Bool) -> some View {
        let cards = Group {
            safetyToggleCard(title: "Reuse existing windows", subtitle: "No duplicate windows of open apps",
                             isOn: optionBinding(project, \.reuseExistingWindows))
            safetyToggleCard(title: "Never move call windows", subtitle: "Zoom, FaceTime, Meet",
                             isOn: optionBinding(project, \.protectCallWindows))
            safetyToggleCard(title: "Ask before display changes", subtitle: lastRestoredText(for: project),
                             isOn: optionBinding(project, \.askBeforeDisplayChanges))
        }
        if stacked {
            VStack(spacing: 12) { cards }
        } else {
            HStack(spacing: 16) { cards }
        }
    }
    
    private func optionBinding(_ project: Project, _ key: WritableKeyPath<RestoreOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { project.restoreOptions[keyPath: key] },
            set: { newVal in
                var updated = project
                updated.restoreOptions[keyPath: key] = newVal
                appState.saveProject(updated)
            }
        )
    }
    
    @ViewBuilder
    private func safetyToggleCard(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            WispSwitch(isOn: isOn, label: title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .wispPanel()
    }
    
    private func appBadgeColor(_ appName: String) -> Color {
        let n = appName.lowercased()
        if n.contains("code") { return Color(hex: 0x2F6FED) }
        if n.contains("terminal") { return Color(hex: 0x2B2B2E) }
        if n.contains("chrome") { return Color(hex: 0xE8710A) }
        if n.contains("figma") { return Color(hex: 0x8E4FE0) }
        if n.contains("safari") { return Color(hex: 0x2F8FED) }
        if n.contains("calculator") { return Color(hex: 0xFEBC2E) }
        if n.contains("notes") { return Color(hex: 0xD9A400) }
        return WispColors.accent
    }
}
