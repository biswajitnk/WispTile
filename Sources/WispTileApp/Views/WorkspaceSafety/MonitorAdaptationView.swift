import SwiftUI
import WispTileCore

/// Board 17 · Monitor adaptation: desk vs laptop layouts for the selected project, and what to do on display changes.
public struct MonitorAdaptationView: View {
    @ObservedObject var appState: AppState

    @AppStorage("displayRule.onDisconnect") private var onDisconnectRule: Int = 0
    @AppStorage("displayRule.onReconnect") private var onReconnectRule: Int = 1
    @State private var dismissedBanner = false

    public init(appState: AppState) {
        self.appState = appState
    }

    private var project: Project? { appState.selectedProject ?? appState.projects.first }
    private var deskLayout: ProjectLayout? {
        project?.layouts.values.first(where: { $0.displaySignature.screenCount > 1 })
    }
    private var laptopLayout: ProjectLayout? {
        project?.layouts.values.first(where: { $0.displaySignature.screenCount == 1 })
    }
    private var externalMissing: Bool { deskLayout != nil && appState.displays.count <= 1 }
    private var builtIn: DisplayInfo? { appState.displays.first(where: { $0.isBuiltIn }) }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            GeometryReader { geo in
                let wide = geo.size.width - 48 >= 720 && geo.size.height >= 480
                Group {
                    if wide {
                        VStack(spacing: 16) {
                            if externalMissing, !dismissedBanner, let p = project { prompt(project: p) }
                            HStack(spacing: 16) { deskCard; laptopCard }
                                .frame(maxHeight: .infinity)
                            rulesCard
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                if externalMissing, !dismissedBanner, let p = project { prompt(project: p) }
                                deskCard.frame(height: 300)
                                laptopCard.frame(height: 300)
                                rulesCard
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
    }

    // MARK: Toolbar
    private var toolbar: some View {
        HStack(spacing: 16) {
            Text("Displays").font(.system(size: 15, weight: .semibold))
            Spacer()
            ForEach(appState.displays.indices, id: \.self) { i in
                let d = appState.displays[i]
                statusPill(color: Color(hex: 0x30B552),
                           text: "\(d.isBuiltIn ? "Built-in" : d.name) · \(Int(d.cocoaFrame.width)) × \(Int(d.cocoaFrame.height))\(d.hasNotch ? " · Notch" : "")",
                           dim: false)
            }
            if externalMissing {
                statusPill(color: Color(hex: 0xB0B0B5), text: "External display · remembered", dim: true)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    private func statusPill(color: Color, text: String, dim: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundColor(dim ? Color(hex: 0x6E6E73) : Color(hex: 0x3A3A3C))
    }

    // MARK: Disconnect prompt
    private func prompt(project: Project) -> some View {
        ViewThatFits(in: .horizontal) {
            promptLayout(project: project, stacked: false)
            promptLayout(project: project, stacked: true)
        }
    }
    
    private func promptLayout(project: Project, stacked: Bool) -> some View {
        let buttons = HStack(spacing: 8) {
            Button("Not Now") { dismissedBanner = true }
                .buttonStyle(WispToolbarSecondaryStyle())
            Button("Switch to Laptop Layout") { appState.triggerRestorePreview(for: project) }
                .buttonStyle(WispToolbarPrimaryStyle())
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                promptText(project: project, wraps: stacked)
                if !stacked { Spacer(minLength: 8); buttons }
            }
            if stacked { buttons.padding(.leading, 52) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wispPanel()
    }
    
    private func promptText(project: Project, wraps: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "display")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color(hex: 0x5E5CE6))
                .cornerRadius(9)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your external display was disconnected").font(.system(size: 13, weight: .semibold))
                Text("Switch “\(project.name)” to your laptop layout? Windows move once and nothing is closed.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .fixedSize(horizontal: !wraps, vertical: true)
            }
        }
    }

    // MARK: Layout cards
    private var deskCard: some View {
        layoutCard(title: "At Desk",
                   trailing: deskLayout == nil ? "Not saved yet" : (externalMissing ? "Returns when reconnected" : "In use"),
                   trailingAccent: false,
                   highlighted: false,
                   caption: deskLayout.map { "\($0.displaySignature.description)" } ?? "Capture with an external display connected to save a desk layout.") {
            if let p = project, let l = deskLayout {
                DeskMiniature(groups: groups(for: p, layout: l))
            } else {
                emptyCanvas
            }
        }
    }

    private var laptopCard: some View {
        layoutCard(title: "On Laptop",
                   trailing: laptopLayout == nil ? "Not saved yet" : (externalMissing ? "Suggested now" : "Saved"),
                   trailingAccent: externalMissing && laptopLayout != nil,
                   highlighted: externalMissing && laptopLayout != nil,
                   caption: laptopLayout == nil
                       ? "Capture with only the built-in display to save a laptop layout."
                       : laptopCaption) {
            if let p = project, let l = laptopLayout {
                ScreenMiniature(windows: groups(for: p, layout: l).flatMap { $0 }, notch: builtIn?.hasNotch ?? false)
                    .padding(14)
            } else {
                emptyCanvas
            }
        }
    }

    /// Apps that live on another display stay minimized on the laptop (Board 17 caption).
    private var laptopCaption: String {
        let off = (project?.items ?? []).filter { $0.displayIndex > 0 }.map(\.appName)
        let lead = off.isEmpty ? "" : "\(ListFormatter.localizedString(byJoining: off)) stay\(off.count == 1 ? "s" : "") minimized. "
        return lead + (builtIn?.hasNotch == true ? "Windows sit below the menu bar, clear of the notch." : "Windows sit below the menu bar.")
    }
    
    private var emptyCanvas: some View {
        Text(project == nil ? "Capture a project to see its layouts" : "No layout saved")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func layoutCard<C: View>(title: String, trailing: String, trailingAccent: Bool, highlighted: Bool, caption: String, @ViewBuilder canvas: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(trailing)
                    .font(.system(size: 12, weight: trailingAccent ? .semibold : .regular))
                    .foregroundColor(trailingAccent ? Color(hex: 0x4A2FC4) : Color(hex: 0x6E6E73))
            }
            .padding(.horizontal, 2)
            ZStack {
                LayoutCanvasView.backdrop
                canvas()
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(caption)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
                .lineLimit(2)
                .padding(.horizontal, 2)
        }
        .padding(highlighted ? 13 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(highlighted ? Color(hex: 0x5B3CE0) : Color.black.opacity(0.08), lineWidth: highlighted ? 2 : 1))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
    }

    /// Project items grouped by display index, each with its rect on that display.
    private func groups(for project: Project, layout: ProjectLayout) -> [[ScreenMiniature.Win]] {
        let count = max(1, layout.displaySignature.screenCount)
        var out = Array(repeating: [ScreenMiniature.Win](), count: count)
        for (i, item) in project.items.enumerated() {
            guard item.displayIndex >= 0, item.displayIndex < count else { continue }
            let d = item.displayIndex
            out[d].append(.init(name: item.appName, rect: LayoutPreviewStore.rect(for: item, index: i, total: project.items.count, layout: layout,
                                                                                 template: TemplateEngine.shared.template(id: project.layoutTemplateId))))
        }
        return out
    }

    // MARK: Rules
    private var rulesCard: some View {
        VStack(spacing: 0) {
            ruleRow("When the external display disconnects",
                    WispSegmented(selection: $onDisconnectRule, options: ["Ask First", "Apply Automatically", "Do Nothing"], horizontalPadding: 14), first: true)
            ruleRow("When it reconnects",
                    WispSegmented(selection: $onReconnectRule, options: ["Ask First", "Restore At Desk Layout", "Do Nothing"], horizontalPadding: 14), first: false)
            if appState.displays.contains(where: { $0.hasNotch }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Built-in display has a notch").font(.system(size: 13))
                        Text("Layouts use the area below the menu bar, so nothing hides behind the notch. Saved layouts also fit Macs without one.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x6E6E73))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Text("Handled automatically")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x1F7A3D))
                }
                .padding(.vertical, 8)
                .frame(minHeight: 50)
                .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            }
        }
        .padding(.horizontal, 16)
        .wispPanel()
    }

    private func ruleRow<C: View>(_ title: String, _ control: C, first: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            control.fixedSize()
        }
        .frame(height: 50)
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
}

/// One display drawn as a dark rounded screen with simple windows (Board 17).
struct ScreenMiniature: View {
    struct Win { let name: String; let rect: CGRect }
    let windows: [Win]
    var notch: Bool = false

    var body: some View {
        GeometryReader { g in
            let menu: CGFloat = notch ? 12 : 0
            let area = CGRect(x: 0, y: menu, width: g.size.width, height: g.size.height - menu)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                if notch {
                    Rectangle().fill(Color.black.opacity(0.45)).frame(height: menu)
                    UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                        .fill(Color.black)
                        .frame(width: g.size.width * 0.15, height: menu)
                        .offset(x: g.size.width * 0.425)
                }
                ForEach(Array(windows.enumerated()), id: \.offset) { _, w in
                    window(w, area: area)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
    }

    private func window(_ w: Win, area: CGRect) -> some View {
        let inset: CGFloat = 0.015
        let r = w.rect
        let width = max(24, area.width * (r.width - inset * 2))
        let height = max(18, area.height * (r.height - inset * 2))
        return VStack(alignment: .leading, spacing: 0) {
            Text(w.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: 0x3A3A3C))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 16)
                .background(Color.black.opacity(0.06))
            if height > 44 {
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(LayoutCanvasView.tint(for: w.name)).frame(width: width * 0.62, height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(LayoutCanvasView.tint(for: w.name)).frame(width: width * 0.42, height: 5)
                }
                .padding(8)
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
        .offset(x: area.minX + area.width * (r.minX + inset), y: area.minY + area.height * (r.minY + inset))
    }
}

/// Desk arrangement: the first display large on top, any others smaller underneath (Board 17, At Desk).
struct DeskMiniature: View {
    let groups: [[ScreenMiniature.Win]]
    var body: some View {
        GeometryReader { g in
            let pad: CGFloat = 14
            let w = g.size.width - pad * 2
            let h = g.size.height - pad * 2
            let others = Array(groups.dropFirst())
            ZStack(alignment: .topLeading) {
                ScreenMiniature(windows: groups.first ?? [])
                    .frame(width: w, height: others.isEmpty ? h : h * 0.68)
                    .offset(x: pad, y: pad)
                ForEach(Array(others.enumerated()), id: \.offset) { i, ws in
                    let ow = min(w * 0.48, (w - CGFloat(others.count - 1) * 12) / CGFloat(others.count))
                    let total = ow * CGFloat(others.count) + CGFloat(others.count - 1) * 12
                    ScreenMiniature(windows: ws)
                        .frame(width: ow, height: h * 0.26)
                        .offset(x: pad + (w - total) / 2 + CGFloat(i) * (ow + 12), y: pad + h * 0.74)
                }
            }
        }
    }
}
