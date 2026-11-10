import SwiftUI
import AppKit
import WispTileCore

/// Board 10 · Repair Workspace: saved layout vs live windows, with per-window fixes.
public struct RepairWorkspaceView: View {
    @ObservedObject var appState: AppState
    @State private var report: DriftReport?
    @State private var liveWindows: [CapturedWindow] = []
    @State private var message: String?
    @State private var foundAt = Date()
    private let previewReport: DriftReport?

    public init(appState: AppState, previewReport: DriftReport? = nil) {
        self.appState = appState
        self.previewReport = previewReport
        _report = State(initialValue: previewReport)
    }

    private var project: Project? { appState.selectedProject ?? appState.projects.first }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Group {
                if project == nil {
                    emptyState("Capture a project first to check for drift.")
                } else if previewReport == nil && !appState.isAccessibilityGranted {
                    emptyState("Allow Accessibility access so WispTile can see where your windows are.")
                } else if let report = report, let project = project {
                    content(report, project: project)
                } else {
                    emptyState("Checking windows…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
        .onAppear { if previewReport == nil { scan() } }
    }

    // MARK: Toolbar
    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Repair Workspace")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button("Update Profile to Match") { updateProfile() }
                .buttonStyle(WispToolbarSecondaryStyle())
                .disabled(project == nil || !appState.isAccessibilityGranted)
            if let report = report, report.hasDrift {
                let n = report.driftedWindows.count
                Button("Repair \(n) Window\(n == 1 ? "" : "s")") { repairAll(report) }
                    .buttonStyle(WispToolbarPrimaryStyle())
            } else {
                Button("Check Again", action: scan)
                    .buttonStyle(WispToolbarPrimaryStyle())
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
        .frame(height: 52)
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    // MARK: Content
    private func content(_ report: DriftReport, project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            alertBar(report)
            GeometryReader { geo in
                let w = geo.size.width
                if w >= 720 {
                    HStack(alignment: .top, spacing: 16) {
                        compareCard(report, project: project)
                            .frame(width: (w - 16) * 1.35 / 2.35)
                        changesColumn(report, project: project)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            compareCard(report, project: project).frame(height: 420)
                            changesColumn(report, project: project)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func alertBar(_ report: DriftReport) -> some View {
        let n = report.driftedWindows.count
        let ok = !report.hasDrift
        return HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 17))
                .foregroundColor(ok ? Color(hex: 0x2A9D4A) : Color(hex: 0x9A5B00))
            (Text(message ?? (ok ? "Everything matches this project." : "\(n) window\(n == 1 ? " no longer matches" : "s no longer match") this project."))
                .fontWeight(.semibold)
             + Text(" Checked \(foundAt.formatted(.relative(presentation: .named))) across \(report.totalWindowsChecked) window\(report.totalWindowsChecked == 1 ? "" : "s")."))
                .font(.system(size: 13))
                .foregroundColor(ok ? Color(hex: 0x1F5A30) : Color(hex: 0x5E3A00))
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ok ? Color(hex: 0xEEF8F0) : Color(hex: 0xFFF6E5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ok ? Color(hex: 0xBFE3C8) : Color(hex: 0xF2DDB0), lineWidth: 1))
    }

    // MARK: Saved layout vs now
    private func compareCard(_ report: DriftReport, project: Project) -> some View {
        let groups = displayGroups(report, project: project)
        let main = groups.max(by: { $0.windows.count + $0.zones.count < $1.windows.count + $1.zones.count })
        let others = groups.filter { $0.id != main?.id }
        let excluded = appState.settings.excludedApps.appNames.sorted()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved layout vs now").font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color(hex: 0x6E6E73), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                            .frame(width: 14, height: 10)
                        Text("Saved zone")
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x5B3CE0)).frame(width: 14, height: 10)
                        Text("Live window")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
            }
            .padding(.horizontal, 2)

            if let main = main {
                RepairCanvas(group: main, compact: false)
                    .frame(maxHeight: .infinity)
            }
            if !others.isEmpty || !excluded.isEmpty {
                HStack(spacing: 12) {
                    ForEach(others) { g in RepairCanvas(group: g, compact: true) }
                    if !excluded.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not touched").font(.system(size: 12, weight: .semibold))
                            Text("\(ListFormatter.localizedString(byJoining: excluded)) \(excluded.count == 1 ? "is" : "are") excluded by your rules.")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: 0x6E6E73))
                                .lineSpacing(2)
                        }
                        .padding(12)
                        .frame(width: others.isEmpty ? nil : 190, alignment: .leading)
                        .frame(maxWidth: others.isEmpty ? .infinity : nil, maxHeight: .infinity, alignment: .leading)
                        .background(Color(hex: 0xF5F5F7))
                        .cornerRadius(8)
                    }
                }
                .frame(height: 118)
            }
        }
        .padding(14)
        .wispPanel()
    }

    // MARK: Changes
    private func changesColumn(_ report: DriftReport, project: Project) -> some View {
        let matching = matchingApps(report, project: project)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(report.driftedWindows.enumerated()), id: \.element.id) { idx, dw in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dw.appName).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(dw.isWrongDisplay ? "Wrong display" : "Moved and resized")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: 0x8A4B05))
                        }
                        Text(dw.driftDescription)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x6E6E73))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(dw.isWrongDisplay ? "Move to Saved Display" : "Snap Back") {
                            let ok = DriftEngine.shared.snapBack(windowId: dw.windowId, to: dw.targetFrame)
                            message = ok ? "\(dw.appName) is back in its zone." : "Could not move \(dw.appName)."
                            scan()
                        }
                        .buttonStyle(WispReportRowButtonStyle())
                    }
                    .padding(.vertical, 12)
                    .overlay(idx == 0 ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                }
                ForEach(Array(matching.enumerated()), id: \.offset) { idx, name in
                    HStack {
                        Text(name).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("Matches").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0x1F7A3D))
                    }
                    .frame(height: 44)
                    .overlay(idx == 0 && report.driftedWindows.isEmpty ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                }
                if report.driftedWindows.isEmpty && matching.isEmpty {
                    Text("None of this project's apps have open windows right now.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x6E6E73))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .wispPanel()

            Spacer(minLength: 0)

            Text("Repair can be undone for 10 minutes. “Update Profile to Match” saves the current arrangement as the new layout instead.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ignore for today") {
                UserDefaults.standard.set(Date(), forKey: "WispTile.repairIgnoredAt")
                appState.selectedNav = .projects
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: 0x4A2FC4))
            .padding(.horizontal, 2)
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(WispColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Data
    private func matchingApps(_ report: DriftReport, project: Project) -> [String] {
        let drifted = Set(report.driftedWindows.map { $0.appName })
        var seen = Set<String>()
        return project.items.compactMap { item in
            guard !drifted.contains(item.appName), !seen.contains(item.appName),
                  liveWindows.contains(where: { $0.bundleId == item.bundleId || $0.appName == item.appName }) else { return nil }
            seen.insert(item.appName)
            return item.appName
        }
    }

    private func displayGroups(_ report: DriftReport, project: Project) -> [RepairCanvas.Group] {
        var displays = appState.displays
        if displays.isEmpty { displays = DisplayManager.shared.getDisplays() }
        func index(for r: CGRect) -> Int {
            displays.firstIndex(where: { $0.axFrame.contains(CGPoint(x: r.midX, y: r.midY)) }) ?? 0
        }
        var groups: [RepairCanvas.Group] = displays.enumerated().map { i, d in
            let size = d.axFrame.size
            return RepairCanvas.Group(id: i,
                                      label: "\(d.isBuiltIn ? "LAPTOP" : (displays.count > 1 ? "EXTERNAL" : "DISPLAY")) · \(Int(size.width)) × \(Int(size.height))",
                                      bounds: d.axVisibleFrame, zones: [], windows: [])
        }
        if groups.isEmpty {
            groups = [RepairCanvas.Group(id: 0, label: "DISPLAY", bounds: CGRect(x: 0, y: 0, width: 1440, height: 900), zones: [], windows: [])]
        }
        for dw in report.driftedWindows {
            let t = index(for: dw.targetFrame), c = index(for: dw.currentFrame)
            if groups.indices.contains(t) { groups[t].zones.append(dw.targetFrame) }
            let suffix: String
            if dw.isWrongDisplay || t != c {
                suffix = "saved on \(groups.indices.contains(t) ? groups[t].label.components(separatedBy: " ·").first!.lowercased() : "another display")"
            } else {
                suffix = dw.deltaXPercent > 3 ? "shifted right" : (dw.deltaXPercent < -3 ? "shifted left" : "resized")
            }
            if groups.indices.contains(c) {
                groups[c].windows.append(.init(appName: dw.appName, label: "\(dw.appName) · \(suffix)", rect: dw.currentFrame, drifted: true))
            }
        }
        for name in matchingApps(report, project: project) {
            if let w = liveWindows.first(where: { $0.appName == name }) {
                let i = displays.indices.contains(w.displayIndex) ? w.displayIndex : 0
                if groups.indices.contains(i) {
                    let b = groups[i].bounds, r = w.relativeRect
                    let frame = CGRect(x: b.minX + r.minX * b.width, y: b.minY + r.minY * b.height,
                                       width: r.width * b.width, height: r.height * b.height)
                    groups[i].zones.append(frame)
                    groups[i].windows.append(.init(appName: name, label: "\(name) · in place", rect: frame, drifted: false))
                }
            }
        }
        // Show only displays that have something on them (always keep at least one).
        let used = groups.filter { !$0.zones.isEmpty || !$0.windows.isEmpty }
        return used.isEmpty ? [groups[0]] : used
    }

    // MARK: Actions
    private func scan() {
        guard previewReport == nil else { return }
        guard let p = project, appState.isAccessibilityGranted else { report = nil; return }
        liveWindows = CaptureEngine.shared.scanDesktop().windows
        report = DriftEngine.shared.detectDrift(for: p)
        foundAt = Date()
    }

    private func repairAll(_ report: DriftReport) {
        let fixed = DriftEngine.shared.repairAll(driftReport: report)
        message = "Repaired \(fixed) of \(report.driftedWindows.count) window\(report.driftedWindows.count == 1 ? "" : "s")."
        scan()
    }

    private func updateProfile() {
        guard let p = project else { return }
        let updated = DriftEngine.shared.updateProjectToMatchLive(project: p)
        appState.saveProject(updated)
        message = "Saved the current arrangement as the new layout for “\(updated.name)”."
        scan()
    }
}

/// One display drawn as a miniature desktop: dashed saved zones plus the live windows on it.
struct RepairCanvas: View {
    struct Win { let appName: String; let label: String; let rect: CGRect; let drifted: Bool }
    struct Group: Identifiable { let id: Int; let label: String; let bounds: CGRect; var zones: [CGRect]; var windows: [Win] }
    let group: Group
    let compact: Bool

    var body: some View {
        GeometryReader { geo in
            let top: CGFloat = compact ? 30 : 34
            let inset: CGFloat = compact ? 14 : 14
            let w = geo.size.width - inset * 2
            let h = geo.size.height - top - (compact ? 12 : 14)
            ZStack(alignment: .topLeading) {
                LayoutCanvasView.backdrop
                Text(group.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(.white.opacity(0.88))
                    .offset(x: 14, y: compact ? 10 : 12)
                ForEach(Array(group.zones.enumerated()), id: \.offset) { _, z in
                    let r = norm(z)
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .frame(width: max(10, w * r.width), height: max(10, h * r.height))
                        .offset(x: inset + w * r.minX, y: top + h * r.minY)
                }
                ForEach(Array(group.windows.enumerated()), id: \.offset) { _, win in
                    let r = norm(win.rect)
                    window(win, width: max(40, w * r.width), height: max(24, h * r.height))
                        .offset(x: inset + w * r.minX, y: top + h * r.minY)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func norm(_ r: CGRect) -> CGRect {
        let b = group.bounds
        guard b.width > 0, b.height > 0 else { return .zero }
        let x = (r.minX - b.minX) / b.width, y = (r.minY - b.minY) / b.height
        let cx = min(max(0, x), 0.95), cy = min(max(0, y), 0.95)
        return CGRect(x: cx, y: cy, width: min(r.width / b.width, 1 - cx), height: min(r.height / b.height, 1 - cy))
    }

    private func window(_ win: Win, width: CGFloat, height: CGFloat) -> some View {
        let tint = LayoutCanvasView.tint(for: win.appName)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color(hex: 0xFF5F57)).frame(width: 6, height: 6)
                Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 6, height: 6)
                Circle().fill(Color(hex: 0x28C840)).frame(width: 6, height: 6)
                Text(win.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: 0x3A3A3C))
                    .lineLimit(1)
                    .padding(.leading, 6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(Color.black.opacity(0.06))
            if height > 60 {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: width * 0.66, height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: width * 0.44, height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: width * 0.56, height: 6)
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(win.drifted ? Color(hex: 0xFFC83D) : Color.black.opacity(0.4), lineWidth: win.drifted ? 2 : 0.5))
        .shadow(color: Color.black.opacity(0.34), radius: 10, y: 6)
    }
}
