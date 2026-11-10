import SwiftUI
import AppKit
import WispTileCore

/// One window drawn on the layout canvas.
public struct CanvasItem: Identifiable {
    public let id: String
    public let appName: String
    public let bundleId: String?
    public let pid: pid_t?
    public let detail: String?
    /// Normalised rect (0…1) inside the display's usable area.
    public let rect: CGRect
    /// Real screenshot of the window, when available.
    public var image: NSImage? = nil
}

/// Shared miniature-desktop canvas used for the saved layout, the live preview and the stored preview image.
public struct LayoutCanvasView: View {
    let items: [CanvasItem]
    var aspect: CGFloat = 16.0 / 10.0
    var gap: CGFloat = 3
    var compact: Bool = false
    /// Fill the whole container instead of keeping the display's aspect ratio.
    var fills: Bool = false
    var showsEmptyMessage: Bool = true
    
    public init(items: [CanvasItem], aspect: CGFloat = 16.0 / 10.0, gap: CGFloat = 3, compact: Bool = false, fills: Bool = false, showsEmptyMessage: Bool = true) {
        self.items = items; self.aspect = aspect; self.gap = gap; self.compact = compact; self.fills = fills
        self.showsEmptyMessage = showsEmptyMessage
    }
    
    /// The design's desktop wallpaper: violet glow top-left, blue glow bottom-right, over deep indigo.
    public static var backdrop: some View {
        GeometryReader { g in
            let r = max(g.size.width, g.size.height)
            ZStack {
                Color(hex: 0x1B1B6B)
                RadialGradient(colors: [Color(hex: 0x7B3FF2), Color(hex: 0x7B3FF2, alpha: 0)],
                               center: UnitPoint(x: 0.18, y: 0.18), startRadius: 0, endRadius: r * 0.55)
                RadialGradient(colors: [Color(hex: 0x2F6BFF), Color(hex: 0x2F6BFF, alpha: 0)],
                               center: UnitPoint(x: 0.88, y: 0.85), startRadius: 0, endRadius: r * 0.52)
            }
        }
    }
    
    public var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = compact ? 8 : 14
            let w = geo.size.width - pad * 2
            let h = geo.size.height - pad * 2
            ZStack(alignment: .topLeading) {
                LayoutCanvasView.backdrop
                
                if items.isEmpty && showsEmptyMessage {
                    Text("No windows to show")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                ForEach(items) { item in
                    let r = item.rect
                    let cw = max(36, w * r.width - gap * 2)
                    let ch = max(28, h * r.height - gap * 2)
                    windowCard(item, width: cw, height: ch)
                        .offset(x: pad + w * r.origin.x + gap, y: pad + h * r.origin.y + gap)
                }
            }
        }
        .modifier(AspectIfNeeded(aspect: fills ? nil : aspect))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8))
    }
    
    /// Soft per-app colour used for the placeholder content lines inside a window.
    static func tint(for appName: String) -> Color {
        let n = appName.lowercased()
        let hex: UInt
        if n.contains("code") { hex = 0x2F6FED }
        else if n.contains("chrome") { hex = 0xE8710A }
        else if n.contains("terminal") || n.contains("iterm") { hex = 0x3C3C43 }
        else if n.contains("figma") { hex = 0x8E4FE0 }
        else if n.contains("safari") { hex = 0x2F8FED }
        else if n.contains("notes") { hex = 0xD9A400 }
        else if n.contains("android") { hex = 0x2E9E55 }
        else if n.contains("slack") { hex = 0x4A154B }
        else { hex = 0x5B3CE0 }
        return Color(hex: hex, alpha: 0.45)
    }
    
    private func windowCard(_ item: CanvasItem, width: CGFloat, height: CGFloat) -> some View {
        let barH: CGFloat = compact ? 12 : 18
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                if !compact {
                    Circle().fill(Color(hex: 0xFF5F57)).frame(width: 6, height: 6)
                    Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 6, height: 6)
                    Circle().fill(Color(hex: 0x28C840)).frame(width: 6, height: 6)
                }
                AppIconView(bundleId: item.bundleId, appName: item.appName, pid: item.pid, size: compact ? 8 : 11)
                    .padding(.leading, compact ? 0 : 2)
                Text(item.appName)
                    .font(.system(size: compact ? 7 : 10, weight: .semibold))
                    .foregroundColor(Color(hex: 0x3A3A3C))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 4 : 8)
            .frame(height: barH)
            .background(Color.black.opacity(0.06))
            
            if let img = item.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: max(0, height - barH), alignment: .top)
                    .clipped()
            } else if !compact {
                VStack(alignment: .leading, spacing: 5) {
                    if let d = item.detail, !d.isEmpty {
                        Text(d)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: 0x6E6E73))
                            .lineLimit(1)
                    }
                    let tint = LayoutCanvasView.tint(for: item.appName)
                    RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: width * 0.62, height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: width * 0.42, height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: width * 0.52, height: 6)
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)
    }
}

private struct AspectIfNeeded: ViewModifier {
    let aspect: CGFloat?
    func body(content: Content) -> some View {
        if let aspect { content.aspectRatio(aspect, contentMode: .fit) } else { content }
    }
}

/// Renders and stores the preview image saved with each project.
@MainActor
enum LayoutPreviewStore {
    static func canvasItems(for project: Project, layout: ProjectLayout?) -> [CanvasItem] {
        let items = project.items
        let template = TemplateEngine.shared.template(id: project.layoutTemplateId)
        return items.enumerated().map { idx, item in
            CanvasItem(id: item.id.uuidString, appName: item.appName, bundleId: item.bundleId, pid: nil,
                       detail: item.pathOrURL, rect: rect(for: item, index: idx, total: items.count, layout: layout, template: template),
                       image: NSImage(contentsOf: StorageEngine.shared.itemShotURL(project: project.id, item: item.id)))
        }
    }
    
    static func rect(for item: ProjectItem, index: Int, total: Int, layout: ProjectLayout?, template: Template? = nil) -> CGRect {
        // A project arranged with a template shows its zones, matching what restore does.
        if let template, let zone = TilingEngine.zone(for: item, index: index, in: template) { return zone.relativeRect }
        if let custom = item.customRelativeRect { return custom }
        if let zoneId = item.zoneId, let zone = layout?.displayZones[item.displayIndex]?.first(where: { $0.id == zoneId }) {
            return zone.relativeRect
        }
        switch total {
        case 1: return CGRect(x: 0.03, y: 0.03, width: 0.94, height: 0.94)
        case 2: return index == 0 ? CGRect(x: 0, y: 0, width: 0.5, height: 1) : CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case 3:
            if index == 0 { return CGRect(x: 0, y: 0, width: 0.6, height: 1) }
            return CGRect(x: 0.6, y: index == 1 ? 0 : 0.5, width: 0.4, height: 0.5)
        default:
            return CGRect(x: CGFloat(index % 2) * 0.5, y: CGFloat((index / 2) % 2) * 0.5, width: 0.5, height: 0.5)
        }
    }
    
    /// Renders the canvas to PNG and stores it as the project's last preview.
    static func save(project: Project) {
        let layout = project.layouts.values.first(where: { $0.displaySignature.screenCount > 1 }) ?? project.layouts.values.first
        let items = canvasItems(for: project, layout: layout)
        guard !items.isEmpty else { return }
        let view = LayoutCanvasView(items: items, aspect: displayAspect()).frame(width: 720)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        if let png = rep.representation(using: .png, properties: [:]) {
            StorageEngine.shared.savePreview(png, for: project.id)
        }
    }
    
    static func image(for id: UUID) -> NSImage? {
        NSImage(contentsOf: StorageEngine.shared.previewURL(for: id))
    }
    
    static func displayAspect() -> CGFloat {
        guard let d = DisplayManager.shared.getDisplays().first(where: { $0.isPrimary }) ?? DisplayManager.shared.getDisplays().first else { return 16.0 / 10.0 }
        let f = d.axVisibleFrame
        return f.height > 0 ? f.width / f.height : 16.0 / 10.0
    }
}
