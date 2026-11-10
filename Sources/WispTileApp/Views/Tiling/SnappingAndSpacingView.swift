import SwiftUI
import AppKit
import WispTileCore

/// Board 16 · Layouts (tab 3): live snap preview on the left, spacing and never-tile apps on the right.
public struct SnappingAndSpacingView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            LayoutsTabBar(appState: appState, selected: 2) { Spacer() }
            GeometryReader { geo in
                let contentW = geo.size.width - 48
                if contentW >= 760 {
                    HStack(alignment: .top, spacing: 20) {
                        previewColumn(height: min(520, geo.size.height - 90))
                            .frame(width: (contentW - 20) * 1.5 / 2.5)
                        settingsColumn
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            previewColumn(height: 340)
                            settingsColumn
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
    }

    // MARK: Preview — zones drawn with the real gap and edge padding
    private func previewColumn(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SnapPreview(gap: appState.settings.gapBetweenWindows, edge: appState.settings.screenEdgePadding)
                .frame(height: max(220, height))
            (Text("Drag a window to a screen edge to see the zones. Hold ")
             + Text("⇧").font(.system(size: 12, design: .monospaced))
             + Text(" to snap anywhere, or press ")
             + Text("⌃⌥←").font(.system(size: 12, design: .monospaced))
             + Text(" to tile from the keyboard."))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x6E6E73))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsColumn: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                Text("Spacing")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                sliderRow("Gap between", value: $appState.settings.gapBetweenWindows, range: 0...20)
                sliderRow("Screen edge", value: $appState.settings.screenEdgePadding, range: 0...22)
                HStack {
                    Text("Animate snapping").font(.system(size: 13))
                    Spacer()
                    WispSwitch(isOn: $appState.settings.animateSnapping, label: "Animate snapping")
                }
                .frame(height: 46)
                .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
            }
            .padding(.horizontal, 16)
            .wispPanel()

            VStack(alignment: .leading, spacing: 0) {
                Text("Never Tile These Apps")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                FlowRow(spacing: 8) {
                    ForEach(appState.settings.excludedApps.appNames.sorted(), id: \.self) { name in
                        AppChip(name: name) { ExcludedAppsActions.remove(name, from: appState) }
                    }
                    DashedAddButton(title: "Add App…") { ExcludedAppsActions.add(to: appState) }
                }
                .padding(.top, 12)
                .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
                Text("Small panels, dialogs and fullscreen apps are never tiled.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x6E6E73))
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .wispPanel()
        }
        .frame(maxWidth: .infinity)
    }

    private func sliderRow(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 13)).frame(width: 96, alignment: .leading)
            WispSlider(value: value, range: range, label: title)
            Text("\(Int(value.wrappedValue)) pt")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x6E6E73))
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 46)
        .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
}

/// Design slider: 4 px track, violet fill, white 16 px knob. Snaps to whole points.
struct WispSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let label: String

    var body: some View {
        GeometryReader { g in
            let span = range.upperBound - range.lowerBound
            let f = span > 0 ? min(1, max(0, (value - range.lowerBound) / span)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xD1D1D6)).frame(height: 4)
                Capsule().fill(Color(hex: 0x5B3CE0)).frame(width: max(0, g.size.width * f), height: 4)
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: g.size.width * f - 8)
            }
            .frame(height: g.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let x = min(max(0, v.location.x / max(1, g.size.width)), 1)
                value = (range.lowerBound + x * span).rounded()
            })
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value)) points")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
}

/// Board 16 illustration: Main + Stack zones with the current spacing, the left zone highlighted
/// as the snap target, and a window being dragged into it.
struct SnapPreview: View {
    let gap: CGFloat
    let edge: CGFloat

    var body: some View {
        GeometryReader { g in
            let bar: CGFloat = 22
            let pad = 6 + edge * 0.7
            let half = gap * 0.7 / 2
            let area = CGRect(x: pad, y: bar + pad, width: g.size.width - pad * 2, height: g.size.height - bar - pad * 2)
            let zones = Template.mainAndStack.zones.map(\.relativeRect)
            ZStack(alignment: .topLeading) {
                LayoutCanvasView.backdrop
                Rectangle().fill(Color.black.opacity(0.35)).frame(height: bar)
                ForEach(Array(zones.enumerated()), id: \.offset) { i, r in
                    let w = max(10, area.width * r.width - half * 2)
                    let h = max(10, area.height * r.height - half * 2)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(i == 0 ? Color(hex: 0x5B3CE0).opacity(0.40) : Color.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(i == 0 ? Color(hex: 0xC3B6FF) : Color.white.opacity(0.45), lineWidth: i == 0 ? 2 : 1.5))
                        .overlay(i == 0 ? Text("Release to snap").font(.system(size: 13, weight: .semibold)).foregroundColor(.white) : nil)
                        .frame(width: w, height: h)
                        .offset(x: area.minX + area.width * r.minX + half, y: area.minY + area.height * r.minY + half)
                }
                draggedWindow
                    .rotationEffect(.degrees(-1.5))
                    .offset(x: g.size.width * 0.22, y: min(150, g.size.height * 0.3))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement()
        .accessibilityLabel("Preview of snap zones with \(Int(gap)) point gaps and \(Int(edge)) point screen edges")
    }

    private var draggedWindow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color(hex: 0xFF5F57)).frame(width: 6, height: 6)
                Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 6, height: 6)
                Circle().fill(Color(hex: 0x28C840)).frame(width: 6, height: 6)
                Text("Window").font(.system(size: 10, weight: .semibold)).foregroundColor(Color(hex: 0x3A3A3C)).padding(.leading, 6)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Color.black.opacity(0.06))
            VStack(alignment: .leading, spacing: 6) {
                let tint = Color(hex: 0x2F6FED, alpha: 0.45)
                RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: 160, height: 6)
                RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: 106, height: 6)
                RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: 136, height: 6)
            }
            .padding(10)
            Spacer(minLength: 0)
        }
        .frame(width: 220, height: 140)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.45), radius: 20, y: 18)
    }
}
