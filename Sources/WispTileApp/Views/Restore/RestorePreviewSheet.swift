import SwiftUI
import AppKit
import WispTileCore

public struct RestorePreviewSheet: View {
    @ObservedObject var appState: AppState
    let project: Project
    @Binding var isPresented: Bool
    
    @State private var unchecked: Set<UUID> = []
    
    public init(appState: AppState, project: Project, isPresented: Binding<Bool>) {
        self.appState = appState
        self.project = project
        self._isPresented = isPresented
    }
    
    public var body: some View {
        let steps = planSteps
        VStack(alignment: .leading, spacing: 0) {
            // Header (Board 8)
            HStack(spacing: 14) {
                Text(String(project.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(hex: project.colorHex))
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restore “\(project.name)”?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                    Text("Nothing has changed yet. Review the plan, then restore.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0x6E6E73))
                }
            }
            .padding(.bottom, 18)
            
            // Before / after
            HStack(spacing: 14) {
                canvasColumn(title: "Now", titleColor: Color(hex: 0x6E6E73), items: liveItems)
                canvasColumn(title: "After", titleColor: WispColors.textPrimary, items: afterItems)
            }
            .frame(height: 210)
            .padding(.bottom, 18)
            
            // Plan
            Text("Plan")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: 0x6E6E73))
                .padding(.bottom, 6)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.item.id) { idx, step in
                        planRow(step, first: idx == 0)
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: steps.count <= 6)
            .wispPanel(cornerRadius: 10)
            
            Spacer(minLength: 16)
            
            // Footer
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x30B552))
                    Text("Snapshot saved first · Undo for 10 minutes")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x6E6E73))
                }
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(WispToolbarSecondaryStyle())
                Button("Restore \(stepCount) Step\(stepCount == 1 ? "" : "s")") {
                    var chosen = project
                    chosen.items.removeAll { unchecked.contains($0.id) }
                    Task { await appState.executeRestore(for: chosen) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(WispToolbarPrimaryStyle())
                .disabled(stepCount == 0)
                .accessibilityLabel("Restore \(project.name)")
            }
        }
        .padding(24)
        .frame(width: 900, height: 640)
        .background(Color.white)
    }
    
    private func canvasColumn(title: String, titleColor: Color, items: [CanvasItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(titleColor)
            LayoutCanvasView(items: items, gap: 2, fills: true)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func planRow(_ step: Step, first: Bool) -> some View {
        let skip = step.verb == "Skip"
        let on = !skip && !unchecked.contains(step.item.id)
        return HStack(spacing: 12) {
            Button {
                guard !skip else { return }
                if unchecked.contains(step.item.id) { unchecked.remove(step.item.id) } else { unchecked.insert(step.item.id) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(on ? Color(hex: 0x5B3CE0) : Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? Color.clear : Color(hex: skip ? 0xD1D1D6 : 0xB0B0B5), lineWidth: 1.5))
                    if on { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundColor(.white) }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(skip)
            .accessibilityLabel("\(step.verb) \(step.item.appName)")
            
            Text(step.verb)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(verbColor(step.verb))
                .frame(width: 56, alignment: .leading)
            
            (Text(step.item.appName).fontWeight(.semibold).foregroundColor(WispColors.textPrimary)
             + Text(" · ").foregroundColor(Color(hex: 0x6E6E73))
             + detailText(step))
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(height: 42)
        .opacity(on || skip ? 1 : 0.55)
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
    
    private func detailText(_ step: Step) -> Text {
        if let code = step.code {
            return Text(code).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: 0x3A3A3C))
                + Text(step.detail.isEmpty ? "" : ", \(step.detail)").foregroundColor(Color(hex: 0x6E6E73))
        }
        return Text(step.detail).foregroundColor(Color(hex: 0x6E6E73))
    }
    
    private func verbColor(_ verb: String) -> Color {
        switch verb {
        case "Reuse": return Color(hex: 0x1F7A3D)
        case "Launch", "Open": return Color(hex: 0x4A2FC4)
        case "Skip": return Color(hex: 0x8A4B05)
        default: return Color(hex: 0x3A3A3C)
        }
    }
    
    // MARK: Real plan data
    private var layout: ProjectLayout? {
        project.layouts.values.first(where: { $0.displaySignature.screenCount == appState.displays.count }) ?? project.layouts.values.first
    }
    
    private var afterItems: [CanvasItem] {
        LayoutPreviewStore.canvasItems(for: project, layout: layout)
    }
    
    private var liveItems: [CanvasItem] {
        CaptureEngine.shared.scanDesktop().windows.map {
            CanvasItem(id: "\($0.id)", appName: $0.appName, bundleId: $0.bundleId, pid: $0.pid, detail: nil, rect: $0.relativeRect)
        }
    }
    
    private struct Step { let item: ProjectItem; let verb: String; let detail: String; var code: String? = nil }
    
    private var planSteps: [Step] {
        let running = NSWorkspace.shared.runningApplications
        return project.items.enumerated().map { idx, item in
            let isRunning = running.contains { ($0.bundleIdentifier?.caseInsensitiveCompare(item.bundleId) == .orderedSame) || $0.localizedName == item.appName }
            let place = describe(LayoutPreviewStore.rect(for: item, index: idx, total: project.items.count, layout: layout,
                                                                  template: TemplateEngine.shared.template(id: project.layoutTemplateId)))
            if appState.settings.excludedApps.appNames.contains(item.appName) || RulesEngine.shared.isCallApp(bundleId: item.bundleId, appName: item.appName) {
                return Step(item: item, verb: "Skip", detail: "your rules protect it")
            }
            if isRunning && project.restoreOptions.reuseExistingWindows && item.launchBehavior == .reuseWindow {
                return Step(item: item, verb: "Reuse", detail: "keep your window, move to \(place)")
            }
            let path = item.pathOrURL.map { ($0.hasPrefix("/") ? ($0 as NSString).abbreviatingWithTildeInPath : $0) }
            return Step(item: item, verb: isRunning ? "Open" : "Launch", detail: "place at \(place)", code: path)
        }
    }
    
    private var stepCount: Int { planSteps.filter { $0.verb != "Skip" && !unchecked.contains($0.item.id) }.count }
    
    private func describe(_ r: CGRect) -> String {
        let cx = r.midX, cy = r.midY
        let horiz = r.width > 0.9 ? "" : (cx < 0.4 ? "left" : (cx > 0.6 ? "right" : "center"))
        let vert = r.height > 0.9 ? "" : (cy < 0.4 ? "top" : (cy > 0.6 ? "bottom" : "middle"))
        if horiz.isEmpty && vert.isEmpty { return "the full screen" }
        let size = r.width < 0.9 ? " \(Int((r.width * 100).rounded()))%" : ""
        return "the \([vert, horiz].filter { !$0.isEmpty }.joined(separator: " "))\(size)"
    }
}
