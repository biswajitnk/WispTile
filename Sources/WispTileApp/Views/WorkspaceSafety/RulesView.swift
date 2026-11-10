import SwiftUI
import AppKit
import WispTileCore

public struct RulesView: View {
    @ObservedObject var appState: AppState
    
    /// Automation rules the user switched off (keyed by their "when" text).
    @AppStorage("WispTile.disabledAutomationRules") private var disabledRulesRaw: String = ""
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar (Board 12)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rules")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                    Text("Safety limits and automatic suggestions")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x6E6E73))
                }
                Spacer()
                Button("New Rule") { addExcludedApp() }
                    .buttonStyle(WispToolbarPrimaryStyle())
                    .help("Exclude an app so WispTile never moves it")
            }
            .padding(.leading, 24)
            .padding(.trailing, 20)
            .frame(height: 52)
            .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Safety") {
                        VStack(spacing: 0) {
                            ruleToggleRow(title: "Reuse existing windows",
                                          subtitle: "Move the open window instead of opening a duplicate",
                                          isOn: Binding(get: { appState.selectedProject?.restoreOptions.reuseExistingWindows ?? true }, set: { v in updateAll { $0.restoreOptions.reuseExistingWindows = v } }),
                                          first: true)
                            ruleToggleRow(title: "Never move call windows",
                                          subtitle: "Zoom, FaceTime and Meet are left where they are",
                                          isOn: Binding(get: { appState.selectedProject?.restoreOptions.protectCallWindows ?? true }, set: { v in updateAll { $0.restoreOptions.protectCallWindows = v } }),
                                          first: false)
                            ruleToggleRow(title: "Ask before display changes",
                                          subtitle: "Show a prompt instead of moving windows on its own",
                                          isOn: Binding(get: { appState.selectedProject?.restoreOptions.askBeforeDisplayChanges ?? true }, set: { v in updateAll { $0.restoreOptions.askBeforeDisplayChanges = v } }),
                                          first: false)
                        }
                        .padding(.horizontal, 16)
                        .wispPanel()
                    }
                    
                    section("Automation") {
                        VStack(spacing: 0) {
                            let triggers = appState.automationTriggers
                            ForEach(Array(triggers.enumerated()), id: \.offset) { idx, t in
                                triggerRow(whenText: t.whenText, actionText: t.actionText, first: idx == 0)
                            }
                        }
                        .padding(.horizontal, 16)
                        .wispPanel()
                    }
                    
                    section("Excluded Apps") {
                        FlowRow(spacing: 8) {
                            ForEach(appState.settings.excludedApps.appNames.sorted(), id: \.self) { name in
                                appPill(name: name)
                            }
                            Button("Add App…") { addExcludedApp() }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: 0x4A2FC4))
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .overlay(Capsule().strokeBorder(Color(hex: 0xB0B0B5), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                                .contentShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .wispPanel()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
    }
    
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: 0x6E6E73))
                .padding(.horizontal, 4)
            content()
        }
    }
    
    private func ruleToggleRow(title: String, subtitle: String, isOn: Binding<Bool>, first: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x6E6E73))
            }
            Spacer()
            WispSwitch(isOn: isOn, label: title)
        }
        .frame(height: 56)
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
    
    private var disabledRules: Set<String> {
        Set(disabledRulesRaw.split(separator: "\n").map(String.init))
    }
    
    private func ruleEnabled(_ key: String) -> Binding<Bool> {
        Binding(
            get: { !disabledRules.contains(key) },
            set: { on in
                var set = disabledRules
                if on { set.remove(key) } else { set.insert(key) }
                disabledRulesRaw = set.sorted().joined(separator: "\n")
            }
        )
    }
    
    private func triggerRow(whenText: String, actionText: String, first: Bool) -> some View {
        // Split "I open ~/path" so the path is shown in monospace like the design.
        let (lead, subject): (String, String) = whenText.hasPrefix("I open ")
            ? ("When I open", String(whenText.dropFirst("I open ".count)))
            : ("When", whenText)
        let isPath = subject.hasPrefix("~") || subject.hasPrefix("/")
        return HStack(spacing: 12) {
            (Text(lead + " ").foregroundColor(Color(hex: 0x6E6E73))
             + Text(subject).fontWeight(.semibold).font(isPath ? .system(size: 12, design: .monospaced) : .system(size: 13)))
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            Text(actionText)
                .font(.system(size: 12))
                .foregroundColor(WispColors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
            WispSwitch(isOn: ruleEnabled(whenText), label: "\(lead) \(subject)")
        }
        .frame(height: 56)
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
    
    private func appPill(name: String) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WispColors.textPrimary)
            Button {
                removeExcludedApp(named: name)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: 0x6E6E73))
            }
            .buttonStyle(.plain)
            .help("Remove \(name) from excluded apps")
            .accessibilityLabel("Remove \(name)")
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(Capsule().fill(Color(hex: 0xF0F0F2)))
    }

    private func updateAll(_ change: (inout Project) -> Void) {
        for var p in appState.projects { change(&p); try? StorageEngine.shared.saveProject(p) }
        appState.refreshAll()
    }
    
    private func appIcon(for name: String) -> some View {
        let ws = NSWorkspace.shared
        let url = ws.urlForApplication(withBundleIdentifier: ["Zoom": "us.zoom.xos", "FaceTime": "com.apple.FaceTime"][name] ?? "")
            ?? ws.runningApplications.first(where: { $0.localizedName == name })?.bundleURL
        if let url = url {
            return AnyView(Image(nsImage: ws.icon(forFile: url.path)).resizable().frame(width: 16, height: 16))
        }
        return AnyView(
            Image(systemName: name.lowercased().contains("meet") ? "video.fill" : "app.fill")
                .font(.system(size: 11))
                .foregroundColor(WispColors.textSecondary)
                .frame(width: 16, height: 16)
        )
    }
    
    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var s = appState.settings
        s.excludedApps.appNames.insert(url.deletingPathExtension().lastPathComponent)
        if let id = Bundle(url: url)?.bundleIdentifier { s.excludedApps.bundleIds.insert(id) }
        appState.settings = s
    }

    private func removeExcludedApp(named name: String) {
        var settings = appState.settings
        settings.excludedApps.appNames.remove(name)

        let knownBundleIds = [
            "Zoom": "us.zoom.xos",
            "FaceTime": "com.apple.FaceTime",
            "System Preferences": "com.apple.systempreferences",
            "System Settings": "com.apple.SystemSettings",
            "Calculator": "com.apple.calculator"
        ]
        if let bundleId = knownBundleIds[name] {
            settings.excludedApps.bundleIds.remove(bundleId)
        }
        let matchingBundleIds = settings.excludedApps.bundleIds.filter { bundleId in
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return false }
            let bundleName = Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent
            return bundleName == name
        }
        settings.excludedApps.bundleIds.subtract(matchingBundleIds)
        if let appURL = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name })?.bundleURL,
           let bundleId = Bundle(url: appURL)?.bundleIdentifier {
            settings.excludedApps.bundleIds.remove(bundleId)
        }

        appState.settings = settings
    }
}

/// Simple wrapping row layout.
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > w, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > b.maxX, x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
