import SwiftUI
import WispTileCore

/// Shared sidebar used by every main-window screen (design: "Shared sidebar").
public struct SidebarView: View {
    @ObservedObject var appState: AppState
    /// The 52 pt band for the window's traffic lights. Off in full screen, where macOS hides them.
    var showsWindowControlsBand = true

    public init(appState: AppState, showsWindowControlsBand: Bool = true) {
        self.appState = appState
        self.showsWindowControlsBand = showsWindowControlsBand
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 52 pt band that holds the window's traffic lights, level with each screen's toolbar.
            Color.clear.frame(height: showsWindowControlsBand ? 52 : 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    sectionHeader("Projects", top: 6)
                    ForEach(appState.projects) { project in
                        projectRow(project)
                    }
                    if appState.projects.isEmpty {
                        Text("No projects yet")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: 0x6E6E73))
                            .padding(.horizontal, 8)
                            .frame(height: 30)
                    }
                    Button {
                        appState.showingCaptureSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            SidebarGlyph(kind: .plus)
                                .stroke(Color(hex: 0x4A2FC4), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                                .frame(width: 14, height: 14)
                            Text("Capture Current Desktop")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: 0x4A2FC4))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SidebarRowStyle(selected: false))
                    .accessibilityLabel("Capture current desktop into a new project")

                    sectionHeader("Library", top: 14)
                    navRow("Snapshots", glyph: .snapshots, nav: .snapshots, count: appState.snapshots.count)
                    navRow("Rules", glyph: .rules, nav: .rules, count: appState.ruleCount)

                    sectionHeader("Tiling", top: 14)
                    navRow("Layouts", glyph: .layouts, nav: .layouts)

                    sectionHeader("System", top: 14)
                    navRow("Displays", glyph: .displays, nav: .displays, count: appState.displays.count)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }

            // Account + settings
            HStack(spacing: 6) {
                Button {
                    appState.settingsTab = 0
                    appState.selectedNav = .settings
                } label: {
                    HStack(spacing: 10) {
                        Text(String((appState.settings.userName.isEmpty ? "Y" : appState.settings.userName).prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(LinearGradient(colors: [Color(hex: 0x7B79F7), Color(hex: 0x4B49D6)],
                                                                     startPoint: UnitPoint(x: 0.33, y: 0.03), endPoint: UnitPoint(x: 0.67, y: 0.97))))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.settings.userName.isEmpty ? "Your Account" : appState.settings.userName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(WispColors.textPrimary)
                                .lineLimit(1)
                            accountSubtitle.lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SidebarRowStyle(selected: false, radius: 8))
                .accessibilityLabel("Profile and settings")

                let onSettings = appState.selectedNav == .settings
                Button {
                    appState.selectedNav = .settings
                } label: {
                    SidebarGlyph(kind: .gear)
                        .stroke(Color(hex: 0x3A3A3C), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 18, height: 18)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SidebarRowStyle(selected: onSettings, radius: 8))
                .accessibilityLabel("Settings")
            }
            .padding(10)
            .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .top)
        }
        .frame(width: 252)
        .background(LinearGradient(colors: [Color(hex: 0xECECEF), Color(hex: 0xE7E7EB)], startPoint: .top, endPoint: .bottom))
        .overlay(Rectangle().fill(Color.black.opacity(0.10)).frame(width: 1), alignment: .trailing)
    }

    private func sectionHeader(_ title: String, top: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: 0x6E6E73))
            .padding(.horizontal, 8)
            .padding(.top, top)
            .padding(.bottom, 4)
    }

    private func isSelected(_ nav: NavigationItem) -> Bool {
        if nav == .layouts { return [.layouts, .templateEditor, .snapping].contains(appState.selectedNav) }
        return appState.selectedNav == nav
    }

    private func navRow(_ title: String, glyph: SidebarGlyph.Kind, nav: NavigationItem, count: Int? = nil) -> some View {
        let sel = isSelected(nav)
        return Button {
            appState.selectedNav = nav
        } label: {
            HStack(spacing: 8) {
                SidebarGlyph(kind: glyph)
                    .stroke(Color(hex: 0x3A3A3C), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 13, weight: sel ? .medium : .regular))
                    .foregroundColor(WispColors.textPrimary)
                Spacer(minLength: 0)
                if let count {
                    Text("\(count)").font(.system(size: 12)).foregroundColor(Color(hex: 0x6E6E73))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowStyle(selected: sel))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(sel ? [.isButton, .isSelected] : .isButton)
    }

    private func projectRow(_ project: Project) -> some View {
        let sel = appState.selectedNav == .projects && appState.selectedProject?.id == project.id
        return Button {
            appState.selectProject(project)
        } label: {
            HStack(spacing: 8) {
                Text(String(project.name.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: project.colorHex))
                    .cornerRadius(5)
                Text(project.name)
                    .font(.system(size: 13, weight: sel ? .medium : .regular))
                    .foregroundColor(WispColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if let shortcut = appState.displayShortcut(for: project) {
                    Text(shortcut)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: 0x6E6E73))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowStyle(selected: sel))
        .accessibilityLabel("Project \(project.name)")
        .accessibilityAddTraits(sel ? [.isButton, .isSelected] : .isButton)
    }

    private var accountSubtitle: some View {
        Text("Free · open source")
            .font(.system(size: 11))
            .foregroundColor(Color(hex: 0x6E6E73))
    }

}

/// Selected rows get the design's 9% grey fill; others show a light hover and press state.
struct SidebarRowStyle: ButtonStyle {
    var selected: Bool
    var radius: CGFloat = 6
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        let fill: Double = selected ? 0.09 : (configuration.isPressed ? 0.10 : (hover ? 0.06 : 0))
        return configuration.label
            .background(RoundedRectangle(cornerRadius: radius).fill(Color.black.opacity(fill)))
            .onHover { hover = $0 }
    }
}

/// The sidebar's line icons, drawn from the design's SVG paths (16 pt grid; plus 14, gear 22).
struct SidebarGlyph: Shape {
    enum Kind { case snapshots, rules, layouts, displays, plus, gear }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let box: CGFloat = kind == .plus ? 14 : (kind == .gear ? 22 : 16)
        let s = min(rect.width, rect.height) / box
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        func line(_ path: inout Path, _ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: p(a.0, a.1)); path.addLine(to: p(b.0, b.1))
        }
        func circle(_ path: inout Path, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            path.addEllipse(in: CGRect(x: rect.minX + (cx - r) * s, y: rect.minY + (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        func rrect(_ path: inout Path, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            path.addRoundedRect(in: CGRect(x: rect.minX + x * s, y: rect.minY + y * s, width: w * s, height: h * s), cornerSize: CGSize(width: r * s, height: r * s))
        }
        var path = Path()
        switch kind {
        case .snapshots:
            circle(&path, 8, 8, 6)
            path.move(to: p(8, 4.5)); path.addLine(to: p(8, 8)); path.addLine(to: p(10.4, 9.4))
        case .rules:
            line(&path, (2.5, 4.5), (9.5, 4.5)); line(&path, (12, 4.5), (13.5, 4.5))
            line(&path, (2.5, 11.5), (4, 11.5)); line(&path, (6.5, 11.5), (13.5, 11.5))
            circle(&path, 10.5, 4.5, 1.5); circle(&path, 5.2, 11.5, 1.5)
        case .layouts:
            rrect(&path, 2, 2.5, 12, 11, 1.8)
            line(&path, (8.6, 2.5), (8.6, 13.5)); line(&path, (8.6, 7.8), (14, 7.8))
        case .displays:
            rrect(&path, 2, 3, 12, 8, 1.5)
            line(&path, (6, 14), (10, 14)); line(&path, (8, 11), (8, 14))
        case .plus:
            line(&path, (7, 2), (7, 12)); line(&path, (2, 7), (12, 7))
        case .gear:
            circle(&path, 11, 11, 3)
            line(&path, (11, 2.5), (11, 4.9)); line(&path, (11, 17.1), (11, 19.5))
            line(&path, (2.5, 11), (4.9, 11)); line(&path, (17.1, 11), (19.5, 11))
            line(&path, (5, 5), (6.7, 6.7)); line(&path, (15.3, 15.3), (17, 17))
            line(&path, (5, 17), (6.7, 15.3)); line(&path, (15.3, 6.7), (17, 5))
        }
        return path
    }
}
