import SwiftUI

public struct WispCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var padding: CGFloat = 16
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(WispColors.cardBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(WispColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

public extension View {
    func wispCard(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(WispCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

public struct WispPrimaryButtonStyle: ButtonStyle {
    public var isDestructive: Bool = false
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isDestructive ? WispColors.error : WispColors.accent)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .shadow(color: (isDestructive ? WispColors.error : WispColors.accent).opacity(0.3), radius: 3, x: 0, y: 1)
    }
}

public struct WispSecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(WispColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 0.5)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

public struct WispBadge: View {
    public let text: String
    public let color: Color
    public let textColor: Color
    
    public init(text: String, color: Color, textColor: Color? = nil) {
        self.text = text
        self.color = color
        self.textColor = textColor ?? color
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

public struct WispLogoView: View {
    public var size: CGFloat = 26
    public var cornerRadius: CGFloat = 6
    
    public init(size: CGFloat = 26, cornerRadius: CGFloat = 6) {
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        if let img = loadLogo() {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.20), lineWidth: 0.5)
                )
                .shadow(
                    color: Color(hex: 0x4B49D6).opacity(size >= 80 ? 0.35 : 0.32),
                    radius: size * 0.125,
                    y: size * 0.09375
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(colors: [WispColors.accentLight, WispColors.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundColor(.white)
                )
        }
    }
    
    private func loadLogo() -> NSImage? {
        if let path = Bundle.main.path(forResource: "WispTileLogo", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        if let path = Bundle.main.path(forResource: "AppLogo", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        let sourceTreeLogo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WispTile logo.png")
        if FileManager.default.fileExists(atPath: sourceTreeLogo.path) {
            return NSImage(contentsOf: sourceTreeLogo)
        }
        return nil
    }
}

public struct TrafficLightsView: View {
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WispColors.trafficRed)
                .frame(width: 12, height: 12)
            Circle()
                .fill(WispColors.trafficYellow)
                .frame(width: 12, height: 12)
            Circle()
                .fill(WispColors.trafficGreen)
                .frame(width: 12, height: 12)
        }
    }
}

/// Design-matched segmented pill control (replaces the stock AppKit segmented picker).
public struct WispSegmented: View {
    @Binding var selection: Int
    let options: [String]
    var horizontalPadding: CGFloat = 12
    public init(selection: Binding<Int>, options: [String], horizontalPadding: CGFloat = 12) {
        self._selection = selection; self.options = options; self.horizontalPadding = horizontalPadding
    }
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, title in
                Button { selection = i } label: {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundColor(selection == i ? WispColors.textPrimary : Color(hex: 0x3A3A3C))
                        .padding(.horizontal, horizontalPadding).padding(.vertical, 4)
                        .background(selection == i ? Color.white : Color.clear)
                        .cornerRadius(6)
                        .shadow(color: selection == i ? Color.black.opacity(0.15) : .clear, radius: 1, y: 0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.06))
        .cornerRadius(8)
    }
}

/// Real application icon (resolved from the running app or its bundle id), with an initials fallback.
public struct AppIconView: View {
    let bundleId: String?
    let appName: String
    var pid: pid_t? = nil
    var size: CGFloat = 28
    
    public init(bundleId: String?, appName: String, pid: pid_t? = nil, size: CGFloat = 28) {
        self.bundleId = bundleId; self.appName = appName; self.pid = pid; self.size = size
    }
    
    private var icon: NSImage? {
        if let pid = pid, let img = NSRunningApplication(processIdentifier: pid)?.icon { return img }
        if let id = bundleId, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }), let img = app.icon { return img }
        return nil
    }
    
    public var body: some View {
        if let img = icon {
            Image(nsImage: img).resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            Text(String(appName.prefix(2)).uppercased())
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(WispColors.accent)
                .cornerRadius(size * 0.22)
        }
    }
}

/// Lays children out side by side when there is room and stacks them vertically when the window gets narrow.
public struct AdaptiveStack<Content: View>: View {
    let breakpoint: CGFloat
    let spacing: CGFloat
    let content: () -> Content
    @State private var narrow = false
    
    public init(breakpoint: CGFloat = 760, spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.breakpoint = breakpoint; self.spacing = spacing; self.content = content
    }
    
    public var body: some View {
        let layout = narrow ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing)) : AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
        // Keep the ViewBuilder closure intact until it is inserted into the layout.
        // Storing its evaluated TupleView as a single value makes AnyLayout see one
        // opaque child, which causes sibling columns to overlap instead of laying out.
        layout { content() }
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { narrow = g.size.width < breakpoint }
                        .onChange(of: g.size.width) { w in narrow = w < breakpoint }
                }
            )
    }
}

/// Design-matched on/off switch (38×22 green track), used on the Projects and Rules screens.
public struct WispSwitch: View {
    @Binding var isOn: Bool
    let label: String
    var compact: Bool = false
    public init(isOn: Binding<Bool>, label: String, compact: Bool = false) { self._isOn = isOn; self.label = label; self.compact = compact }
    public var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Color(hex: 0x30B552) : Color(hex: 0xD1D1D6))
                Circle().fill(Color.white)
                    .frame(width: compact ? 16 : 18, height: compact ? 16 : 18)
                    .shadow(color: Color.black.opacity(0.3), radius: 1.5, y: 1)
                    .padding(2)
            }
            .frame(width: compact ? 34 : 38, height: compact ? 20 : 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

/// Small bordered button used inside cards and rows (24 px tall, 12 pt).
public struct WispSmallButtonStyle: ButtonStyle {
    public var destructive: Bool = false
    public init(destructive: Bool = false) { self.destructive = destructive }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(destructive ? Color(hex: 0xB3261E) : WispColors.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(configuration.isPressed ? Color(hex: 0xE6E6EB) : Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(destructive ? Color(hex: 0xB3261E).opacity(0.35) : Color.black.opacity(0.14), lineWidth: 1))
    }
}

public extension View {
    /// White rounded card with the design's hairline border and soft shadow, no padding.
    func wispPanel(cornerRadius: CGFloat = 12) -> some View {
        self.background(Color.white)
            .cornerRadius(cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
    }
}

/// The design's 30 px toolbar primary button (#5B3CE0).
public struct WispToolbarPrimaryStyle: ButtonStyle {
    public var fullWidth = false
    public init(fullWidth: Bool = false) { self.fullWidth = fullWidth }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(configuration.isPressed ? Color(hex: 0x3F25AD) : Color(hex: 0x5B3CE0))
            .cornerRadius(7)
            .shadow(color: Color.black.opacity(0.2), radius: 0.5, y: 0.5)
    }
}

/// The design's 30 px toolbar secondary button.
public struct WispToolbarSecondaryStyle: ButtonStyle {
    public var fullWidth = false
    public init(fullWidth: Bool = false) { self.fullWidth = fullWidth }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .foregroundColor(WispColors.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(configuration.isPressed ? Color(hex: 0xE6E6EB) : Color.white)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 0.5, y: 0.5)
    }
}

/// 28 px primary button used inside settings rows.
public struct WispSmallPrimaryStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(configuration.isPressed ? Color(hex: 0x3F25AD) : Color(hex: 0x5B3CE0))
            .cornerRadius(7)
    }
}
