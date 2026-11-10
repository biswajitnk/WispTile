import SwiftUI
import AppKit
import WispTileCore

/// Board 14 · Layouts (tab 1): active layout, templates, where new windows go, behaviour and shortcuts.
public struct AutomaticTilingView: View {
    @ObservedObject var appState: AppState

    @AppStorage("WispTile.selectedLayoutTemplate") private var selectedTemplateName: String = "Main + Stack"
    /// Per-app zone preference chosen in "Where New Windows Go" (app name → zone id), stored as JSON.
    @AppStorage("WispTile.newWindowZones") private var zoneChoicesRaw: String = "{}"
    @State private var feedback: String? = nil
    @State private var liveWindows: [LiveWindow] = []
    
    struct LiveWindow { let name: String; let bundleId: String?; let pid: pid_t; let excluded: Bool; let minX: CGFloat }

    public init(appState: AppState) {
        self.appState = appState
    }

    private var allTemplates: [Template] {
        Template.builtInPresets + appState.templates.filter { t in !t.isBuiltIn && !Template.builtInPresets.contains(where: { $0.id == t.id }) }
    }

    private var template: Template {
        allTemplates.first(where: { $0.name == selectedTemplateName }) ?? Template.mainAndStack
    }

    public var body: some View {
        VStack(spacing: 0) {
            LayoutsTabBar(appState: appState, selected: 0) {
                Spacer()
                Button("Tile Now", action: tileNow)
                    .buttonStyle(WispToolbarSecondaryStyle())
                    .help("Tile the open windows with “\(template.name)” now")
                HStack(spacing: 10) {
                    Text("Auto-Tile").font(.system(size: 13, weight: .medium))
                    WispSwitch(isOn: $appState.settings.autoTileNewWindows, label: "Auto-Tile")
                }
                .padding(.leading, 6)
            }

            GeometryReader { geo in
                let contentW = geo.size.width - 48
                let wide = contentW >= 780 && geo.size.height >= 560
                Group {
                    if wide {
                        VStack(spacing: 16) {
                            if !appState.isAccessibilityGranted { AccessibilityBanner() }
                            if let feedback = feedback { feedbackBanner(feedback) }
                            HStack(alignment: .top, spacing: 16) {
                                layoutCard.frame(width: (contentW - 16) * 1.25 / 2.25)
                                VStack(spacing: 16) {
                                    newWindowsCard.frame(maxHeight: .infinity, alignment: .top)
                                    behaviorCard
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(maxHeight: .infinity)
                            shortcutsBar
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                if !appState.isAccessibilityGranted { AccessibilityBanner() }
                                if let feedback = feedback { feedbackBanner(feedback) }
                                layoutCard.frame(height: 440)
                                newWindowsCard
                                behaviorCard
                                shortcutsBar
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
        .onAppear(perform: refreshWindows)
    }

    private func feedbackBanner(_ text: String) -> some View {
        let ok = (text.hasPrefix("Tiled") || text.hasPrefix("Applied") || text.hasPrefix("Windows returned")) && !text.contains("can’t")
        return HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle" : "info.circle").foregroundColor(ok ? Color(hex: 0x2A9D4A) : Color(hex: 0x8A4B05))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ok ? Color(hex: 0x1F5A30) : Color(hex: 0x5E3A00))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Dismiss") { withAnimation { feedback = nil } }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x4A2FC4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(ok ? Color(hex: 0xEEF8F0) : Color(hex: 0xFFF6E5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ok ? Color(hex: 0xBFE3C8) : Color(hex: 0xF2DDB0), lineWidth: 1))
    }

    // MARK: Layout card (canvas + templates)
    private var layoutCard: some View {
        let tiled = liveWindows.filter { !$0.excluded }
        let items: [CanvasItem] = template.zones.enumerated().compactMap { i, z in
            guard let w = tiled.first(where: { zoneIndex(for: $0.name, among: tiled) == i }) else { return nil }
            return CanvasItem(id: z.id, appName: w.name, bundleId: w.bundleId, pid: w.pid, detail: nil, rect: z.relativeRect)
        }
        let filled = Set(items.map(\.id))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.name).font(.system(size: 13, weight: .semibold))
                Spacer()
                let projectsUsing = appState.projects.filter { $0.layoutTemplateId == template.id }.count
                Text(projectsUsing == 0 ? "Used by Tile Now and Auto-Tile"
                     : "Used by \(projectsUsing) project\(projectsUsing == 1 ? "" : "s"), Tile Now and Auto-Tile")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
            }
            .padding(.horizontal, 2)

            LayoutCanvasView(items: items, gap: max(2, template.gap / 3), fills: true, showsEmptyMessage: false)
                .overlay(emptyZones(filled: filled))
                .overlay(zoneBadges)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text("Templates")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: 0x6E6E73))
                Spacer()
                Button("Edit Selected") {
                    appState.templateToEdit = template
                    appState.selectedNav = .templateEditor
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x4A2FC4))
                Button("New Template…") {
                    appState.templateToEdit = Template(name: "New Template", zones: [Zone(id: "1", name: "Zone 1", relativeRect: CGRect(x: 0, y: 0, width: 1, height: 1))])
                    appState.selectedNav = .templateEditor
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: 0x4A2FC4))
                .padding(.leading, 10)
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allTemplates) { t in
                        let sel = t.name == template.name
                        Button { selectedTemplateName = t.name } label: {
                            VStack(spacing: 5) {
                                TemplateThumbnail(template: t, selected: sel)
                                    .frame(width: 64, height: 40)
                                Text(t.name)
                                    .font(.system(size: 11, weight: sel ? .semibold : .regular))
                                    .foregroundColor(sel ? Color(hex: 0x4A2FC4) : Color(hex: 0x3A3A3C))
                                    .lineLimit(1)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(t.name) template\(sel ? ", selected" : "")")
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .wispPanel()
    }

    /// Zones with no window yet: a dashed outline where the next new window will go.
    private func emptyZones(filled: Set<String>) -> some View {
        GeometryReader { g in
            let pad: CGFloat = 14, gap: CGFloat = max(2, template.gap / 3)
            let w = g.size.width - pad * 2, h = g.size.height - pad * 2
            ForEach(template.zones.filter { !filled.contains($0.id) }) { z in
                emptyZone(z, area: CGRect(x: pad, y: pad, width: w, height: h), gap: gap)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func emptyZone(_ z: Zone, area: CGRect, gap: CGFloat) -> some View {
        let r = z.relativeRect
        let w: CGFloat = max(30, area.width * r.width - gap * 2)
        let h: CGFloat = max(30, area.height * r.height - gap * 2)
        let x: CGFloat = area.minX + area.width * r.minX + gap
        let y: CGFloat = area.minY + area.height * r.minY + gap
        let label = Text("\(z.name) · new window")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 6)
        return RoundedRectangle(cornerRadius: 7)
            .fill(Color.white.opacity(0.18))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
            .overlay(label)
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }
    
    /// Numbered purple badges in the corner of each zone (Board 14).
    private var zoneBadges: some View {
        GeometryReader { g in
            let pad: CGFloat = 14
            let w = g.size.width - pad * 2, h = g.size.height - pad * 2
            ForEach(Array(template.zones.enumerated()), id: \.offset) { i, z in
                let r = z.relativeRect
                Text("\(i + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color(hex: 0x5B3CE0)))
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                    .offset(x: pad + w * r.minX + 10, y: pad + h * r.maxY - 34)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Where new windows go
    private var zoneChoices: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(zoneChoicesRaw.utf8))) ?? [:]
    }

    private func setZone(_ zoneId: String?, for app: String) {
        var c = zoneChoices
        c[app] = zoneId
        if let data = try? JSONEncoder().encode(c), let s = String(data: data, encoding: .utf8) { zoneChoicesRaw = s }
    }

    /// Zone of the given app's window among the tileable windows (shared rule with Tile Now).
    private func zoneIndex(for app: String, among tiled: [LiveWindow]) -> Int {
        let zones = TilingEngine.assignZones(apps: tiled.map(\.name), minX: tiled.map(\.minX), template: template, choices: zoneChoices)
        guard let k = tiled.firstIndex(where: { $0.name == app }) else { return 0 }
        return zones[k]
    }

    private var newWindowsCard: some View {
        let tiled = liveWindows.filter { !$0.excluded }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Where New Windows Go").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: refreshWindows) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(hex: 0x6E6E73))
                .help("Check open windows again")
                .accessibilityLabel("Refresh open windows")
            }
            .padding(.bottom, 8)

            if liveWindows.isEmpty {
                Text(emptyWindowsMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(liveWindows.enumerated()), id: \.offset) { _, w in
                        HStack(spacing: 12) {
                            AppIconView(bundleId: w.bundleId, appName: w.name, pid: w.pid, size: 26)
                            Text(w.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            zoneMenu(for: w, tiled: tiled)
                        }
                        .frame(height: 44)
                        .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                    }
                }
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .wispPanel()
    }

    private func zoneMenu(for w: LiveWindow, tiled: [LiveWindow]) -> some View {
        let label: String
        if w.excluded {
            label = "Never tile"
        } else {
            let i = zoneIndex(for: w.name, among: tiled)
            let z = template.zones[i]
            label = z.name.isEmpty ? "Zone \(i + 1)" : "Zone \(i + 1) · \(z.name)"
        }
        return Menu {
            ForEach(Array(template.zones.enumerated()), id: \.offset) { i, z in
                Button("Zone \(i + 1) · \(z.name)") {
                    if w.excluded { ExcludedAppsActions.remove(w.name, from: appState) }
                    setZone(z.id, for: w.name)
                    refreshWindows()
                }
            }
            Divider()
            if w.excluded {
                Button("Allow Tiling") { ExcludedAppsActions.remove(w.name, from: appState); refreshWindows() }
            } else {
                Button("Never Tile") { ExcludedAppsActions.add(name: w.name, bundleId: w.bundleId, to: appState); refreshWindows() }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 12, weight: w.excluded ? .medium : .regular))
            .foregroundColor(w.excluded ? Color(hex: 0x8A4B05) : WispColors.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Zone for \(w.name)")
    }

    // MARK: Behaviour
    private var behaviorCard: some View {
        VStack(spacing: 0) {
            toggleRow("Tile new windows automatically", isOn: $appState.settings.autoTileNewWindows, first: true)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Snap while dragging a window").font(.system(size: 13)).foregroundColor(Color(hex: 0x6E6E73))
                    Text("Coming in a later version").font(.system(size: 11)).foregroundColor(Color(hex: 0x6E6E73))
                }
                Spacer()
                WispSwitch(isOn: .constant(false), label: "Snap while dragging a window, not available yet")
                    .disabled(true)
                    .opacity(0.5)
            }
            .frame(height: 46)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            toggleRow("Re-tile after display changes", isOn: $appState.settings.retileAfterDisplayChange, first: false)
        }
        .padding(.horizontal, 16)
        .wispPanel()
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, first: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            WispSwitch(isOn: isOn, label: title)
        }
        .frame(height: 46)
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }

    // MARK: Shortcuts
    private var shortcutsBar: some View {
        HStack(spacing: 18) {
            Text("Shortcuts").font(.system(size: 13, weight: .semibold))
            shortcut("⌃⌥←", "Left half") { showResult("Left half", appState.tileActiveWindow(command: .leftHalf)) }
            shortcut("⌃⌥→", "Right half") { showResult("Right half", appState.tileActiveWindow(command: .rightHalf)) }
            shortcut("⌃⌥↩", "Maximize") { showResult("Maximize", appState.tileActiveWindow(command: .maximize)) }
            shortcut("⌃⌥Z", "Undo last tile") {
                appState.undoRestore()
                withAnimation { feedback = "Windows returned to their previous positions." }
            }
            Spacer(minLength: 8)
            Text("Tile Now and Auto-Tile use the selected layout")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
                .lineLimit(1)
                .layoutPriority(-1)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .wispPanel()
    }

    private func shortcut(_ keys: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                KeyCap(keys: keys)
                Text(label).font(.system(size: 12)).foregroundColor(Color(hex: 0x3A3A3C))
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .help("\(label) (\(keys))")
    }

    @State private var offDesktop = 0
    
    private var emptyWindowsMessage: String {
        let fullScreen = NSApp.windows.contains { $0.styleMask.contains(.fullScreen) }
        var text = "No other app windows on this desktop. WispTile arranges the windows on the desktop you’re on."
        if offDesktop > 0 {
            text += " \(offDesktop) window\(offDesktop == 1 ? " is" : "s are") on other desktops, in full screen or minimized."
        }
        if fullScreen {
            text += " WispTile is in full screen, which gives it a desktop of its own: exit full screen (⌃⌘F) to tile your other windows."
        }
        return text
    }
    
    // MARK: Actions
    private func refreshWindows() {
        offDesktop = WindowManager.shared.countWindowsOffCurrentDesktop()
        let excluded = appState.settings.excludedApps
        let (wins, _) = CaptureEngine.shared.scanDesktop()
        var seen = Set<String>()
        liveWindows = wins.compactMap { w in
            guard seen.insert(w.appName).inserted else { return nil } // one row per app
            let isExcluded = w.isCallApp || excluded.appNames.contains(w.appName) || excluded.bundleIds.contains(w.bundleId)
            return LiveWindow(name: w.appName, bundleId: w.bundleId, pid: w.pid, excluded: isExcluded, minX: w.relativeRect.minX)
        }
    }

    private func tileNow() {
        let outcome = appState.tileOpenWindows(presetName: template.name)
        withAnimation {
            switch outcome {
            case .tiled(let n, let tooWide) where n > 0:
                feedback = "Tiled \(n) window\(n == 1 ? "" : "s") with “\(template.name)”."
                if !tooWide.isEmpty {
                    let names = ListFormatter.localizedString(byJoining: tooWide)
                    feedback! += " \(names) can’t be made narrow enough for this layout, so \(tooWide.count == 1 ? "it overlaps" : "they overlap") the gaps. Try a layout with fewer columns, such as Halves or Main + Stack."
                }
            case .tiled:
                feedback = "macOS didn’t let WispTile move those windows. Check Accessibility access."
            case .noAccessibility:
                feedback = "Allow Accessibility access first; WispTile can’t move windows without it."
            case .noWindows:
                feedback = emptyWindowsMessage
            }
        }
        refreshWindows()
    }

    private func showResult(_ action: String, _ result: WindowMoveResult) {
        withAnimation {
            switch result {
            case .success: feedback = "Applied “\(action)” to the frontmost window."
            case .partial(_, let reason): feedback = "Moved with adjustment: \(reason)"
            case .failed(let error): feedback = "Could not tile: \(error)"
            }
        }
    }
}
