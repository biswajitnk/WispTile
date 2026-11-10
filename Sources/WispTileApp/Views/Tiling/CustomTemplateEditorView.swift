import SwiftUI
import AppKit
import WispTileCore

/// Board 15 · Layouts (tab 2): draw, select, split and merge zones on a dotted grid; inspect and save templates.
public struct CustomTemplateEditorView: View {
    @ObservedObject var appState: AppState

    private enum Tool: Int { case draw, select, split, merge }

    @State private var template: Template = Template(name: "Custom Layout", zones: Template.mainAndStack.zones)
    @State private var saved: Template?
    @State private var selectedZoneId: String = "1"
    @State private var tool: Tool = .select
    @AppStorage("WispTile.editorSnapToGrid") private var snapToGrid = true
    @AppStorage("WispTile.editorGridCols") private var gridCols = 12
    @AppStorage("WispTile.editorGridRows") private var gridRows = 8
    @State private var drawRect: CGRect?
    @State private var dragOrigin: CGRect?
    @State private var message: String?
    @State private var loaded = false

    public init(appState: AppState) {
        self.appState = appState
    }

    private var userTemplates: [Template] {
        appState.templates.filter { t in !t.isBuiltIn && !Template.builtInPresets.contains(where: { $0.id == t.id }) }
    }

    private var selectedIndex: Int? { template.zones.firstIndex(where: { $0.id == selectedZoneId }) }

    /// Below this width the template name and buttons leave the toolbar and the inspector moves under the canvas.
    @State private var compact = false
    
    public var body: some View {
        VStack(spacing: 0) {
            LayoutsTabBar(appState: appState, selected: 1) {
                if compact {
                    Spacer()
                } else {
                    Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1, height: 20)
                    Text("Template").font(.system(size: 13)).foregroundColor(Color(hex: 0x6E6E73))
                    nameField.frame(width: 200)
                    Spacer()
                    templateButtons
                }
            }
            
            if compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            nameField.frame(maxWidth: .infinity)
                            templateButtons
                        }
                        toolRow
                        canvas.frame(height: 300)
                        statusLine
                        templatesStrip
                        inspector
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        toolRow
                        canvas
                            .frame(maxHeight: .infinity)
                        statusLine
                        templatesStrip
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    inspector
                        .frame(width: 280)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .background(GeometryReader { g in
            Color.clear
                .onAppear { compact = g.size.width < 900 }
                .onChange(of: g.size.width) { compact = $0 < 900 }
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
        .onAppear(perform: load)
        .onChange(of: appState.templateToEdit) { t in if t != nil { load() } }
    }

    private var hint: String {
        switch tool {
        case .draw: return "Drag on the canvas to draw a zone."
        case .select: return "Click a zone to select it. Drag it to move, or drag its handles to resize."
        case .split: return "Click a zone to split it in two along its longer side."
        case .merge: return "Select a zone, then click a neighbour to merge them."
        }
    }

    // MARK: Toolbar pieces
    private var nameField: some View {
        TextField("Template name", text: $template.name)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
            .accessibilityLabel("Template name")
    }
    
    @ViewBuilder
    private var templateButtons: some View {
        Button("Cancel") { revert() }
            .buttonStyle(WispToolbarSecondaryStyle())
            .disabled(saved == template)
        Button("Save Template") { save() }
            .buttonStyle(WispToolbarPrimaryStyle())
            .keyboardShortcut("s", modifiers: .command)
    }
    
    private var statusLine: some View {
        Text(message ?? hint)
            .font(.system(size: 12))
            .foregroundColor(message == nil ? Color(hex: 0x6E6E73) : Color(hex: 0x1F7A3D))
            .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: Tool row
    /// Tools on the left and snap controls on the right; the snap controls drop to a second line when narrow.
    private var toolRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { toolButtons; Spacer(); gridControls }
            VStack(alignment: .leading, spacing: 8) { toolButtons; HStack(spacing: 12) { gridControls } }
        }
    }
    
    private var toolButtons: some View {
        HStack(spacing: 0) {
            toolButton(.draw, "Draw Zone", icon: "plus")
            toolButton(.select, "Select", icon: nil)
            toolButton(.split, "Split", icon: nil)
            toolButton(.merge, "Merge", icon: nil)
        }
        .padding(2)
        .background(Color.black.opacity(0.06))
        .cornerRadius(8)
        .fixedSize()
    }
    
    @ViewBuilder
    private var gridControls: some View {
        HStack(spacing: 8) {
            Text("Snap to Grid").font(.system(size: 12))
            WispSwitch(isOn: $snapToGrid, label: "Snap to grid")
        }
        .fixedSize()
        Menu {
            ForEach([(12, 8), (8, 6), (6, 4), (16, 10)], id: \.0) { c, r in
                Button("\(c) × \(r) grid") { gridCols = c; gridRows = r }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(gridCols) × \(gridRows) grid")
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
    
    private func toolButton(_ t: Tool, _ title: String, icon: String?) -> some View {
        let on = tool == t
        return Button { tool = t; message = nil } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(on ? WispColors.textPrimary : Color(hex: 0x3A3A3C))
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(on ? Color.white : Color.clear)
            .cornerRadius(6)
            .shadow(color: on ? Color.black.opacity(0.18) : .clear, radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: Canvas
    private var canvas: some View {
        GeometryReader { g in
            let inset: CGFloat = 12
            let area = CGRect(x: inset, y: inset, width: g.size.width - inset * 2, height: g.size.height - inset * 2)
            ZStack(alignment: .topLeading) {
                LayoutCanvasView.backdrop
                dotGrid(area)
                ForEach(Array(template.zones.enumerated()), id: \.element.id) { i, z in
                    zoneView(z, number: i + 1, area: area)
                }
                if let d = drawRect {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: 0x5B3CE0).opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                        .frame(width: d.width * area.width, height: d.height * area.height)
                        .offset(x: area.minX + d.minX * area.width, y: area.minY + d.minY * area.height)
                }
                if tool == .draw {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(drawGesture(area))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(minHeight: 260)
    }

    private func dotGrid(_ area: CGRect) -> some View {
        Canvas { ctx, _ in
            guard gridCols > 0, gridRows > 0 else { return }
            for c in 0...gridCols {
                for r in 0...gridRows {
                    let p = CGPoint(x: area.minX + area.width * CGFloat(c) / CGFloat(gridCols),
                                    y: area.minY + area.height * CGFloat(r) / CGFloat(gridRows))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)), with: .color(.white.opacity(0.35)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func zoneView(_ z: Zone, number: Int, area: CGRect) -> some View {
        let sel = z.id == selectedZoneId
        let r = z.relativeRect
        let gap: CGFloat = 3
        let w = max(20, r.width * area.width - gap * 2)
        let h = max(20, r.height * area.height - gap * 2)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(sel ? 0.22 : 0.14))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(sel ? 1 : 0.5), lineWidth: sel ? 2 : 1.5))
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color(hex: 0x5B3CE0)))
                Text(z.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                    .lineLimit(1)
            }
            .padding(10)
            if sel {
                Text("\(pct(r.width)) × \(pct(r.height))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color(hex: 0x1E1E20).opacity(0.88))
                    .cornerRadius(6)
                    .frame(width: w, height: h)
                handles(width: w, height: h, area: area)
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .offset(x: area.minX + r.minX * area.width + gap, y: area.minY + r.minY * area.height + gap)
        .onTapGesture { tapZone(z) }
        .gesture(tool == .select && sel ? moveGesture(area) : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zone \(number), \(z.name), \(pct(r.width)) by \(pct(r.height))")
        .accessibilityAddTraits(.isButton)
    }

    private func handles(width w: CGFloat, height h: CGFloat, area: CGRect) -> some View {
        let spots: [(CGFloat, CGFloat)] = [(0, 0), (0.5, 0), (1, 0), (0, 0.5), (1, 0.5), (0, 1), (0.5, 1), (1, 1)]
        return ZStack(alignment: .topLeading) {
            ForEach(Array(spots.enumerated()), id: \.offset) { _, s in
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .overlay(Rectangle().stroke(Color(hex: 0x5B3CE0), lineWidth: 1))
                    .offset(x: s.0 * w - 4, y: s.1 * h - 4)
                    .gesture(resizeGesture(hx: s.0, hy: s.1, area: area))
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    // MARK: Gestures
    private func snap(_ v: CGFloat, _ n: Int) -> CGFloat {
        guard snapToGrid, n > 0 else { return v }
        return (v * CGFloat(n)).rounded() / CGFloat(n)
    }

    private func norm(_ p: CGPoint, _ area: CGRect) -> CGPoint {
        CGPoint(x: min(1, max(0, (p.x - area.minX) / area.width)), y: min(1, max(0, (p.y - area.minY) / area.height)))
    }

    private func drawGesture(_ area: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                let a = norm(v.startLocation, area), b = norm(v.location, area)
                drawRect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            }
            .onEnded { _ in
                defer { drawRect = nil }
                guard let d = drawRect else { return }
                let x0 = snap(d.minX, gridCols), y0 = snap(d.minY, gridRows)
                let x1 = snap(d.maxX, gridCols), y1 = snap(d.maxY, gridRows)
                guard x1 - x0 >= 0.04, y1 - y0 >= 0.04 else { return }
                let id = nextZoneId()
                template.zones.append(Zone(id: id, name: "Zone \(template.zones.count + 1)", relativeRect: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)))
                selectedZoneId = id
                tool = .select
            }
    }

    private func moveGesture(_ area: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                guard let i = selectedIndex else { return }
                if dragOrigin == nil { dragOrigin = template.zones[i].relativeRect }
                guard let o = dragOrigin else { return }
                let dx = v.translation.width / area.width, dy = v.translation.height / area.height
                let x = min(max(0, o.minX + dx), 1 - o.width), y = min(max(0, o.minY + dy), 1 - o.height)
                template.zones[i].relativeRect = CGRect(x: x, y: y, width: o.width, height: o.height)
            }
            .onEnded { _ in
                dragOrigin = nil
                guard let i = selectedIndex else { return }
                var r = template.zones[i].relativeRect
                r.origin.x = min(snap(r.minX, gridCols), 1 - r.width)
                r.origin.y = min(snap(r.minY, gridRows), 1 - r.height)
                template.zones[i].relativeRect = r
            }
    }

    private func resizeGesture(hx: CGFloat, hy: CGFloat, area: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                guard let i = selectedIndex else { return }
                if dragOrigin == nil { dragOrigin = template.zones[i].relativeRect }
                guard let o = dragOrigin else { return }
                let dx = v.translation.width / area.width, dy = v.translation.height / area.height
                var minX = o.minX, maxX = o.maxX, minY = o.minY, maxY = o.maxY
                if hx == 0 { minX = min(max(0, o.minX + dx), o.maxX - 0.05) }
                if hx == 1 { maxX = max(min(1, o.maxX + dx), o.minX + 0.05) }
                if hy == 0 { minY = min(max(0, o.minY + dy), o.maxY - 0.05) }
                if hy == 1 { maxY = max(min(1, o.maxY + dy), o.minY + 0.05) }
                template.zones[i].relativeRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            .onEnded { _ in
                dragOrigin = nil
                guard let i = selectedIndex else { return }
                let r = template.zones[i].relativeRect
                let x0 = snap(r.minX, gridCols), y0 = snap(r.minY, gridRows)
                let x1 = max(x0 + 0.05, snap(r.maxX, gridCols)), y1 = max(y0 + 0.05, snap(r.maxY, gridRows))
                template.zones[i].relativeRect = CGRect(x: x0, y: y0, width: min(1, x1) - x0, height: min(1, y1) - y0)
            }
    }

    private func tapZone(_ z: Zone) {
        message = nil
        switch tool {
        case .select, .draw:
            selectedZoneId = z.id
        case .split:
            let r = z.relativeRect
            template = TemplateEngine.shared.splitZone(in: template, zoneId: z.id, orientation: r.width >= r.height ? .vertical : .horizontal)
            selectedZoneId = z.id
        case .merge:
            if z.id == selectedZoneId { return }
            let before = template.zones.count
            template = TemplateEngine.shared.mergeZones(in: template, zoneId1: selectedZoneId, zoneId2: z.id)
            if template.zones.count == before { message = "Those zones can’t be merged into a rectangle." }
        }
    }

    // MARK: Templates strip
    private var templatesStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Templates")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: 0x6E6E73))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(userTemplates) { t in
                        let sel = t.id == template.id
                        Button { open(t) } label: {
                            VStack(spacing: 5) {
                                TemplateThumbnail(template: t, selected: sel).frame(width: 64, height: 40)
                                Text(t.name)
                                    .font(.system(size: 11, weight: sel ? .semibold : .regular))
                                    .foregroundColor(sel ? Color(hex: 0x4A2FC4) : Color(hex: 0x3A3A3C))
                                    .lineLimit(1)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { newTemplate() } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(hex: 0xB0B0B5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .overlay(Image(systemName: "plus").font(.system(size: 13)).foregroundColor(Color(hex: 0x6E6E73)))
                                .frame(width: 64, height: 40)
                                .padding(2)
                            Text("New Template").font(.system(size: 11)).foregroundColor(Color(hex: 0x3A3A3C))
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Inspector
    private var inspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let i = selectedIndex {
                zoneCard(i)
            }
            spacingCard
            Spacer(minLength: 0)
            Text("Templates adapt to other displays by percentage, so one template works on every screen. Add a laptop-specific version in Displays.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func zoneCard(_ i: Int) -> some View {
        let z = template.zones[i]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Zone \(i + 1)").font(.system(size: 13, weight: .semibold))
            labeled("Name") {
                field(TextField("Name", text: Binding(get: { template.zones[i].name }, set: { template.zones[i].name = $0 })))
            }
            HStack(spacing: 10) {
                labeled("X") { percentField(i, \.origin.x) }
                labeled("Y") { percentField(i, \.origin.y) }
            }
            HStack(spacing: 10) {
                labeled("Width") { percentField(i, \.size.width) }
                labeled("Height") { percentField(i, \.size.height) }
            }
            HStack {
                Text("Default app").font(.system(size: 13))
                Spacer()
                defaultAppMenu(i)
            }
            HStack {
                Text("Stack extra windows").font(.system(size: 13))
                Spacer()
                WispSwitch(isOn: Binding(get: { template.zones[i].stackExtraWindows }, set: { template.zones[i].stackExtraWindows = $0 }), label: "Stack extra windows")
            }
            HStack(spacing: 8) {
                Button { duplicateZone(z) } label: { Text("Duplicate").frame(maxWidth: .infinity) }
                    .buttonStyle(WispReportRowButtonStyle())
                Button { deleteZone(z) } label: { Text("Delete Zone").foregroundColor(Color(hex: 0xB3261E)).frame(maxWidth: .infinity) }
                    .buttonStyle(WispReportRowButtonStyle())
                    .disabled(template.zones.count <= 1)
            }
        }
        .padding(16)
        .wispPanel()
    }

    private func labeled<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundColor(Color(hex: 0x6E6E73))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field<F: View>(_ f: F) -> some View {
        f.textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.14), lineWidth: 1))
    }

    private func percentField(_ i: Int, _ key: WritableKeyPath<CGRect, CGFloat>) -> some View {
        field(TextField("0%", text: Binding(
            get: { pct(template.zones[i].relativeRect[keyPath: key]) },
            set: { text in
                let digits = text.filter { $0.isNumber || $0 == "." }
                guard let v = Double(digits) else { return }
                var r = template.zones[i].relativeRect
                r[keyPath: key] = CGFloat(min(100, max(0, v)) / 100)
                r.size.width = min(max(0.05, r.width), 1 - r.minX)
                r.size.height = min(max(0.05, r.height), 1 - r.minY)
                template.zones[i].relativeRect = r
            }
        )))
    }

    private func defaultAppMenu(_ i: Int) -> some View {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { a -> (String, String)? in
                guard let id = a.bundleIdentifier, let n = a.localizedName else { return nil }
                return (n, id)
            }
            .sorted { $0.0 < $1.0 }
        let current = template.zones[i].defaultAppBundleId
        let name = current.flatMap { id in apps.first(where: { $0.1 == id })?.0 ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent } ?? "None"
        return Menu {
            Button("None") { template.zones[i].defaultAppBundleId = nil }
            Divider()
            ForEach(apps, id: \.1) { app in
                Button(app.0) { template.zones[i].defaultAppBundleId = app.1 }
            }
        } label: {
            HStack(spacing: 4) {
                Text(name)
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var spacingCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gap between zones").font(.system(size: 13))
                Spacer()
                Text("\(Int(template.gap)) px").font(.system(size: 13, weight: .medium))
                miniStepper(value: $template.gap, range: 0...40)
            }
            .frame(height: 44)
            HStack {
                Text("Screen edge padding").font(.system(size: 13))
                Spacer()
                Text("\(Int(template.padding)) px").font(.system(size: 13, weight: .medium))
                miniStepper(value: $template.padding, range: 0...60)
            }
            .frame(height: 44)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            HStack {
                Text("Works on").font(.system(size: 13))
                Spacer()
                Text(worksOn).font(.system(size: 13)).foregroundColor(Color(hex: 0x6E6E73)).lineLimit(1)
            }
            .frame(height: 44)
            .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
        }
        .padding(.horizontal, 16)
        .wispPanel()
    }

    private var worksOn: String {
        guard let d = appState.displays.first(where: { $0.isPrimary }) ?? appState.displays.first else { return "Any display" }
        return "\(d.isBuiltIn ? "Built-in" : "External") \(Int(d.cocoaFrame.width)) × \(Int(d.cocoaFrame.height))"
    }

    private func miniStepper(value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(spacing: 0) {
            Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 2) } label: {
                Image(systemName: "chevron.up").font(.system(size: 7, weight: .bold)).frame(width: 20, height: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase")
            Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
            Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 2) } label: {
                Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold)).frame(width: 20, height: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease")
        }
        .frame(width: 20)
        .foregroundColor(Color(hex: 0x3A3A3C))
        .background(Color.white)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.14), lineWidth: 1))
        .padding(.leading, 6)
    }

    // MARK: Actions
    private func pct(_ v: CGFloat) -> String { "\(Int((v * 100).rounded()))%" }

    private func nextZoneId() -> String {
        let n = (template.zones.compactMap { Int($0.id) }.max() ?? 0) + 1
        return "\(n)"
    }

    private func load() {
        if let t = appState.templateToEdit {
            appState.templateToEdit = nil
            open(t)
        } else if !loaded {
            if let t = userTemplates.first { open(t) } else { open(Template(name: "Custom Layout", zones: Template.mainAndStack.zones)) }
        }
        loaded = true
    }

    private func open(_ t: Template) {
        template = t
        saved = userTemplates.first(where: { $0.id == t.id })
        selectedZoneId = t.zones.first?.id ?? "1"
        message = nil
    }

    private func newTemplate() {
        open(Template(name: "New Template", zones: [Zone(id: "1", name: "Zone 1", relativeRect: CGRect(x: 0, y: 0, width: 1, height: 1))]))
    }

    private func revert() {
        if let s = saved { open(s) } else { newTemplate() }
    }

    private func save() {
        var t = template
        if t.isBuiltIn || Template.builtInPresets.contains(where: { $0.id == t.id }) {
            t = Template(name: t.name, zones: t.zones, gap: t.gap, padding: t.padding, isBuiltIn: false)
        }
        if t.name.trimmingCharacters(in: .whitespaces).isEmpty { t.name = "Custom Layout" }
        do {
            try StorageEngine.shared.saveTemplate(t)
            appState.refreshAll()
            template = t
            saved = t
            message = "Saved “\(t.name)”. It now appears in Layouts."
        } catch {
            message = "Could not save the template: \(error.localizedDescription)"
        }
    }

    private func duplicateZone(_ z: Zone) {
        var r = z.relativeRect
        r.origin.x = min(1 - r.width, r.minX + 0.05)
        r.origin.y = min(1 - r.height, r.minY + 0.05)
        let id = nextZoneId()
        template.zones.append(Zone(id: id, name: "\(z.name) Copy", relativeRect: r, defaultAppBundleId: z.defaultAppBundleId, stackExtraWindows: z.stackExtraWindows))
        selectedZoneId = id
    }

    private func deleteZone(_ z: Zone) {
        guard template.zones.count > 1 else { return }
        template.zones.removeAll { $0.id == z.id }
        selectedZoneId = template.zones.first?.id ?? "1"
    }
}
