import SwiftUI
import AppKit
import WispTileCore

/// Board 20 · Settings (tab 2): every global shortcut, a real conflict warning, and a quick switcher preview.
public struct KeyboardShortcutsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private var rows: [(label: String, keys: String)] {
        var r: [(String, String)] = [("Open quick switcher", appState.settings.quickSwitcherShortcut)]
        for p in appState.projects {
            if let k = appState.displayShortcut(for: p) { r.append(("Switch to \(p.name)", k)) }
        }
        r.append(("Repair current workspace", appState.settings.repairShortcut))
        r.append(("Capture current desktop", appState.settings.captureShortcut))
        r.append(("Pause tiling", "⌃⌥P"))
        return r
    }

    public var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width - 48 >= 720
            ScrollView {
                Group {
                    if wide {
                        HStack(alignment: .top, spacing: 20) {
                            listColumn.frame(maxWidth: .infinity)
                            switcherPreview.frame(maxWidth: .infinity).frame(height: 560)
                        }
                    } else {
                        VStack(spacing: 20) {
                            listColumn
                            switcherPreview.frame(height: 420)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
    }

    // MARK: Shortcut list
    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        Text(row.label).font(.system(size: 13)).lineLimit(1)
                        Spacer()
                        Text(row.keys)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0xF0F0F2))
                            .cornerRadius(6)
                            .overlay(appState.hotkeyConflicts.contains(row.keys) ? RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0xE08A00), lineWidth: 1) : nil)
                    }
                    .frame(height: 48)
                    .overlay(i == 0 ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                }
            }
            .padding(.horizontal, 16)
            .wispPanel()

            if let first = appState.hotkeyConflicts.sorted().first {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x8A4B05))
                    (Text("\(first) may conflict. ").fontWeight(.semibold)
                     + Text(appState.hotkeyConflicts.count > 1
                            ? "\(appState.hotkeyConflicts.count) shortcuts are already used by other apps, so they won’t work here until the other app releases them."
                            : "Another app already uses this shortcut, so it won’t work here until that app releases it."))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x5C3303))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Keyboard Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: 0x5C3303))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color(hex: 0x8A4B05).opacity(0.14))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(hex: 0xFFF4E0))
                .cornerRadius(10)
            }

            Text("Shortcuts work from anywhere, including when the menu bar icon is hidden.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
        }
    }

    // MARK: Quick switcher preview
    private var switcherPreview: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                LayoutCanvasView.backdrop
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(Color(hex: 0x6E6E73))
                        Text("Switch project…").font(.system(size: 15)).foregroundColor(WispColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
                    VStack(spacing: 0) {
                        ForEach(Array(appState.projects.prefix(5).enumerated()), id: \.element.id) { i, p in
                            switcherRow(p, highlighted: i == 0)
                        }
                        HStack(spacing: 10) {
                            Text("+")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: 0x6E6E73))
                                .frame(width: 24, height: 24)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: 0x9A9AA0), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
                            Text("Capture Current Desktop").font(.system(size: 13)).foregroundColor(Color(hex: 0x4A2FC4))
                            Spacer()
                            Text(appState.settings.captureShortcut).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: 0x6E6E73))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .overlay(appState.projects.isEmpty ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                        .padding(.top, appState.projects.isEmpty ? 0 : 4)
                    }
                    .padding(6)
                }
                .background(Color(hex: 0xF6F6F8).opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.4), radius: 25, y: 20)
                .padding(.horizontal, g.size.width * 0.1)
                .padding(.top, min(90, g.size.height * 0.16))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview of the quick switcher")
    }

    private func switcherRow(_ p: Project, highlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Text(String(p.name.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(highlighted ? Color.white.opacity(0.25) : Color(hex: p.colorHex))
                .cornerRadius(6)
            Text(p.name)
                .font(.system(size: 13, weight: highlighted ? .semibold : .regular))
                .foregroundColor(highlighted ? .white : WispColors.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(appState.displayShortcut(for: p) ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(highlighted ? .white : Color(hex: 0x6E6E73))
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(highlighted ? Color(hex: 0x5B3CE0) : Color.clear)
        .cornerRadius(8)
    }
}
