import SwiftUI
import AppKit
import WispTileCore

public struct EditProjectView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var project: Project
    @State private var confirmingDelete = false
    
    private let palette: [String] = ["#5E5CE6", "#AF52DE", "#30B552", "#E8710A", "#E5484D", "#2F8FED"]
    
    public init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        self._isPresented = isPresented
        _project = State(initialValue: appState.selectedProject ?? Project(name: "Untitled Project"))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geo in
                ScrollView {
                    let w = geo.size.width - 48
                    Group {
                        if w >= 720 {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 16) { generalCard; itemsCard }
                                    .frame(width: (w - 16) * 1.4 / 2.4)
                                VStack(spacing: 16) { restoreOptionsCard; manageCard }
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: 16) { generalCard; itemsCard; restoreOptionsCard; manageCard }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
        .alert("Delete “\(project.name)”?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                appState.deleteProject(project)
                isPresented = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the project and its saved layouts. Your apps and windows are not touched.")
        }
    }
    
    // MARK: Toolbar (Board 7)
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Button("Projects") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: 0x4A2FC4))
                    .keyboardShortcut(.cancelAction)
                    .help("Back to Projects without saving")
                Text("›").foregroundColor(Color(hex: 0xB0B0B5))
                Text("Edit Project")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(WispColors.textPrimary)
            Spacer()
            Button("Done") {
                if project.name.trimmingCharacters(in: .whitespaces).isEmpty { project.name = "Untitled Project" }
                project.updatedAt = Date()
                appState.saveProject(project)
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(WispToolbarPrimaryStyle())
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
        .frame(height: 52)
        .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }
    
    // MARK: General
    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                fieldColumn("Name") {
                    designField(TextField("Project name", text: $project.name))
                }
                fieldColumn("Shortcut") {
                    designField(TextField("⌃⌥1", text: Binding(
                        get: { project.shortcut ?? appState.displayShortcut(for: project) ?? "" },
                        set: { project.shortcut = $0.isEmpty ? nil : $0 }
                    )).multilineTextAlignment(.center).font(.system(size: 13, design: .monospaced)))
                }
                .frame(width: 110)
            }
            HStack(spacing: 10) {
                Text("Color")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .frame(width: 50, alignment: .leading)
                ForEach(palette, id: \.self) { hex in
                    let on = project.colorHex.caseInsensitiveCompare(hex) == .orderedSame
                    Button { project.colorHex = hex } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 22, height: 22)
                            .padding(2)
                            .background(Circle().fill(Color.white))
                            .padding(2)
                            .background(Circle().fill(on ? Color(hex: hex) : Color.clear))
                            .padding(-4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)\(on ? ", selected" : "")")
                }
            }
        }
        .padding(16)
        .wispPanel()
    }
    
    private func designField<F: View>(_ field: F) -> some View {
        field
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
    }
    
    private func fieldColumn<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: 0x6E6E73))
            content()
        }
    }
    
    // MARK: Items
    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Apps and Items")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 6) {
                    Button("Add App…", action: addApp).buttonStyle(WispSmallButtonStyle())
                    Button("Add Folder…", action: addFolder).buttonStyle(WispSmallButtonStyle())
                    Button("Add URL…", action: addURL).buttonStyle(WispSmallButtonStyle())
                }
            }
            .frame(height: 46)
            
            if project.items.isEmpty {
                Text("Nothing here yet. Add an app, a folder or a web address.")
                    .font(.system(size: 12))
                    .foregroundColor(WispColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 54)
                    .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            }
            
            ForEach(project.items.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    AppIconView(bundleId: project.items[i].bundleId, appName: project.items[i].appName, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.items[i].appName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(itemDetail(project.items[i]))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: 0x6E6E73))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                    if let t = chosenTemplate {
                        zoneMenu(i, template: t)
                    }
                    Menu {
                        Button("Reuse window") { project.items[i].launchBehavior = .reuseWindow }
                        Button("Always open new") { project.items[i].launchBehavior = .alwaysOpenNew }
                    } label: {
                        Text(project.items[i].launchBehavior == .reuseWindow ? "Reuse window ▾" : "Always open new ▾")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x3A3A3C))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    Button("Remove") { project.items.remove(at: i) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xB3261E))
                        .accessibilityLabel("Remove \(project.items[i].appName)")
                }
                .frame(height: 54)
                .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            }
        }
        .padding(.horizontal, 16)
        .wispPanel()
    }
    
    /// Built-in layouts plus the ones saved in the Template Editor.
    private var allTemplates: [Template] { appState.allTemplates }
    
    private var chosenTemplate: Template? {
        guard let id = project.layoutTemplateId else { return nil }
        return allTemplates.first(where: { $0.id == id })
    }
    
    private var arrangeMenu: some View {
        Menu {
            Button("As captured") { project.layoutTemplateId = nil }
            Divider()
            ForEach(allTemplates) { t in
                Button(t.name) {
                    project.layoutTemplateId = t.id
                    // Start each app in the zone matching its place in the list.
                    for i in project.items.indices {
                        if let z = TilingEngine.zone(for: project.items[i], index: i, in: t) { project.items[i].templateZoneId = z.id }
                    }
                }
            }
        } label: {
            pill(chosenTemplate?.name ?? "As captured")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Arrange with")
    }
    
    private func zoneMenu(_ i: Int, template: Template) -> some View {
        let zone = TilingEngine.zone(for: project.items[i], index: i, in: template)
        let n = zone.flatMap { z in template.zones.firstIndex(where: { $0.id == z.id }) }.map { $0 + 1 } ?? 1
        return Menu {
            ForEach(Array(template.zones.enumerated()), id: \.offset) { k, z in
                Button("Zone \(k + 1) · \(z.name)") { project.items[i].templateZoneId = z.id }
            }
        } label: {
            pill("Zone \(n)")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Zone for \(project.items[i].appName)")
    }
    
    private func pill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold))
        }
        .font(.system(size: 12))
        .foregroundColor(WispColors.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Color.white)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
    }
    
    private func itemDetail(_ item: ProjectItem) -> String {
        guard let p = item.pathOrURL, !p.isEmpty else { return "Window position only" }
        if p.hasPrefix("/") || p.hasPrefix("~") {
            let short = (p as NSString).abbreviatingWithTildeInPath
            return item.appName.lowercased().contains("terminal") ? "cwd \(short)" : "folder \(short)"
        }
        return p
    }
    
    // MARK: Restore options
    private var restoreOptionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Restore Options")
                .font(.system(size: 13, weight: .semibold))
                .frame(height: 46)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Spaces").font(.system(size: 13))
                WispSegmented(selection: Binding(
                    get: { project.restoreOptions.spacesMode == .currentSpace ? 0 : 1 },
                    set: { project.restoreOptions.spacesMode = $0 == 0 ? .currentSpace : .originalSpaces }
                ), options: ["Current Space", "Original Spaces"])
                Text("Original Spaces puts each window back on the desktop it was captured on.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Fullscreen apps and Stage Manager").font(.system(size: 13))
                WispSegmented(selection: Binding(
                    get: { project.restoreOptions.fullscreenPolicy == .skipAndReport ? 0 : 1 },
                    set: { project.restoreOptions.fullscreenPolicy = $0 == 0 ? .skipAndReport : .askEachTime }
                ), options: ["Skip and report", "Ask each time"])
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Arrange with").font(.system(size: 13))
                    Spacer()
                    arrangeMenu
                }
                Text(chosenTemplate == nil
                     ? "Windows come back exactly where they were when you captured them."
                     : "Apps fill the layout’s zones; pick a zone for each app under Apps and Items. Spacing follows Snapping and Spacing.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            
            HStack {
                Text("Saved for").font(.system(size: 13))
                Spacer()
                Button(layoutsSummary) {
                    isPresented = false
                    appState.selectedNav = .displays
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: 0x4A2FC4))
            }
            .frame(height: 46)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
        }
        .padding(.horizontal, 16)
        .wispPanel()
    }
    
    private var layoutsSummary: String {
        var names: [String] = []
        if project.layouts.values.contains(where: { $0.displaySignature.screenCount > 1 }) { names.append("At Desk") }
        if project.layouts.values.contains(where: { $0.displaySignature.screenCount == 1 }) { names.append("On Laptop") }
        return names.isEmpty ? "None saved yet" : names.joined(separator: ", ")
    }
    
    // MARK: Duplicate / Delete
    private var manageCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Duplicate Project").font(.system(size: 13))
                Spacer()
                Button("Duplicate", action: duplicate).buttonStyle(WispSmallButtonStyle())
            }
            .frame(height: 46)
            HStack {
                Text("Delete Project").font(.system(size: 13)).foregroundColor(Color(hex: 0xB3261E))
                Spacer()
                Button("Delete…") { confirmingDelete = true }
                    .buttonStyle(WispSmallButtonStyle(destructive: true))
            }
            .frame(height: 46)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
        }
        .padding(.horizontal, 16)
        .wispPanel()
    }
    
    // MARK: Actions
    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.deletingPathExtension().lastPathComponent
        let bundleId = Bundle(url: url)?.bundleIdentifier ?? "unknown.\(name.lowercased())"
        project.items.append(ProjectItem(appName: name, bundleId: bundleId, displayIndex: 0, customRelativeRect: nextRect()))
    }
    
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        project.items.append(ProjectItem(appName: "Finder", bundleId: "com.apple.finder",
                                         pathOrURL: (url.path as NSString).abbreviatingWithTildeInPath,
                                         customRelativeRect: nextRect()))
    }
    
    private func addURL() {
        let alert = NSAlert()
        alert.messageText = "Add a web address"
        alert.informativeText = "It opens in your default browser when the project is restored."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let urlString = raw.contains("://") ? raw : "https://\(raw)"
        var name = "Safari", bundle = "com.apple.Safari"
        if let url = URL(string: urlString), let app = NSWorkspace.shared.urlForApplication(toOpen: url),
           let b = Bundle(url: app) {
            bundle = b.bundleIdentifier ?? bundle
            name = app.deletingPathExtension().lastPathComponent
        }
        project.items.append(ProjectItem(appName: name, bundleId: bundle, pathOrURL: urlString, customRelativeRect: nextRect()))
    }
    
    /// Default placement for a newly added item: the largest free half of the screen.
    private func nextRect() -> CGRect {
        project.items.count % 2 == 0 ? CGRect(x: 0, y: 0, width: 0.5, height: 1) : CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
    }
    
    private func duplicate() {
        let copy = Project(name: "\(project.name) Copy", colorHex: project.colorHex, shortcut: nil,
                       items: project.items.map { ProjectItem(id: $0.id, appName: $0.appName, bundleId: $0.bundleId, pathOrURL: $0.pathOrURL, displayIndex: $0.displayIndex, zoneId: $0.zoneId, customRelativeRect: $0.customRelativeRect, launchBehavior: $0.launchBehavior) },
                       layouts: project.layouts, restoreOptions: project.restoreOptions)
        var arranged = copy
        arranged.layoutTemplateId = project.layoutTemplateId
        for i in arranged.items.indices where i < project.items.count {
            arranged.items[i].templateZoneId = project.items[i].templateZoneId
        }
        appState.saveProject(arranged)
        isPresented = false
    }
}
