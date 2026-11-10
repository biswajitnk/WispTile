import SwiftUI
import WispTileCore

/// Boards 14–16: the 52 px toolbar shared by the three Layouts tabs, with per-tab trailing controls.
struct LayoutsTabBar<Trailing: View>: View {
    @ObservedObject var appState: AppState
    let selected: Int
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            WispSegmented(
                selection: Binding(
                    get: { selected },
                    set: { appState.selectedNav = $0 == 0 ? .layouts : ($0 == 1 ? .templateEditor : .snapping) }
                ),
                options: ["Layouts", "Template Editor", "Snapping and Spacing"],
                horizontalPadding: 14
            )
            .fixedSize()
            trailing()
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
        .frame(height: 52)
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }
}

extension LayoutsTabBar where Trailing == EmptyView {
    init(appState: AppState, selected: Int) {
        self.init(appState: appState, selected: selected) { EmptyView() }
    }
}

/// Design key cap (⌃⌥← etc.).
struct KeyCap: View {
    let keys: String
    var body: some View {
        Text(keys)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(WispColors.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color(hex: 0xF0F0F2))
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.10), lineWidth: 1))
    }
}

/// Grey app chip used for excluded / never-tile apps, with a remove button.
struct AppChip: View {
    let name: String
    let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WispColors.textPrimary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: 0x6E6E73))
            }
            .buttonStyle(.plain)
            .help("Remove \(name)")
            .accessibilityLabel("Remove \(name)")
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(Capsule().fill(Color(hex: 0xF0F0F2)))
    }
}

/// Dashed "Add App…" pill.
struct DashedAddButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: 0x4A2FC4))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .overlay(Capsule().strokeBorder(Color(hex: 0xB0B0B5), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .contentShape(Capsule())
    }
}

/// Miniature of a template: indigo backdrop with white zones (template strips on Boards 14–15).
struct TemplateThumbnail: View {
    let template: Template
    let selected: Bool
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x2A3070))
                ForEach(template.zones) { z in zoneBlock(z.relativeRect, in: g.size) }
            }
        }
        .padding(2)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color(hex: 0x5B3CE0) : Color.clear, lineWidth: 2))
    }
    
    private func zoneBlock(_ r: CGRect, in size: CGSize) -> some View {
        let iw: CGFloat = size.width - 8
        let ih: CGFloat = size.height - 8
        let w: CGFloat = max(4, iw * r.width - 3)
        let h: CGFloat = max(4, ih * r.height - 3)
        let x: CGFloat = 4 + iw * r.minX + 1.5
        let y: CGFloat = 4 + ih * r.minY + 1.5
        return RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.92))
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }
}

/// Excluded-app helpers shared by Layouts, Snapping and Rules.
@MainActor
enum ExcludedAppsActions {
    static func add(to appState: AppState, prompt: String = "Never Tile") {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = prompt
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var s = appState.settings
        s.excludedApps.appNames.insert(url.deletingPathExtension().lastPathComponent)
        if let id = Bundle(url: url)?.bundleIdentifier { s.excludedApps.bundleIds.insert(id) }
        appState.settings = s
    }

    static func add(name: String, bundleId: String?, to appState: AppState) {
        var s = appState.settings
        s.excludedApps.appNames.insert(name)
        if let id = bundleId { s.excludedApps.bundleIds.insert(id) }
        appState.settings = s
    }

    static func remove(_ name: String, from appState: AppState) {
        var s = appState.settings
        s.excludedApps.appNames.remove(name)
        if let url = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name })?.bundleURL,
           let id = Bundle(url: url)?.bundleIdentifier {
            s.excludedApps.bundleIds.remove(id)
        }
        appState.settings = s
    }
}

/// Shown on screens that move windows when macOS hasn't granted Accessibility access yet.
struct AccessibilityBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: 0x8A4B05))
                .frame(width: 28, height: 28)
                .background(Color(hex: 0xFFF1D6))
                .cornerRadius(7)
            VStack(alignment: .leading, spacing: 2) {
                Text("WispTile can’t move windows yet").font(.system(size: 13, weight: .semibold))
                Text("Allow Accessibility access in System Settings. If WispTile is already listed, remove it with − and add it again, then reopen WispTile.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Allow Access…") {
                _ = WindowManager.shared.isAccessibilityGranted(promptIfNot: true)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(WispToolbarPrimaryStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: 0xFFF6E5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xF2DDB0), lineWidth: 1))
    }
}
