import SwiftUI
import AppKit
import WispTileCore

/// Board 25 · Errors and edge cases: the four recovery states, laid out as a 2 × 2 grid of cards.
public struct ErrorsAndEdgeCasesView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { g in
            let wide = g.size.width >= 760
            let cards = [AnyView(accessibilityCard), AnyView(skippedCard), AnyView(offlineCard), AnyView(seatsCard)]
            ScrollView {
                if wide {
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 16) { cards[0]; cards[1] }
                            .frame(height: max(280, (g.size.height - 56) / 2))
                        HStack(alignment: .top, spacing: 16) { cards[2]; cards[3] }
                            .frame(height: max(280, (g.size.height - 56) / 2))
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 16) { ForEach(0..<4, id: \.self) { cards[$0].frame(minHeight: 260) } }
                        .padding(20)
                }
            }
        }
        .background(Color(hex: 0xEBEBEF))
    }

    // MARK: Cards
    private var accessibilityCard: some View {
        card(icon: "lock", tint: 0x8A4B05, tileFill: 0xFFF1D6,
             title: "Window control is turned off",
             message: "macOS removed the Accessibility permission, so WispTile can't move windows. Projects and layouts are safe. Restoring and tiling are paused.") {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(WispToolbarPrimaryStyle())
            Button("Remind Me Later") {}
                .buttonStyle(WispToolbarSecondaryStyle())
        }
    }

    private var skippedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Restored with 4 items skipped").font(.system(size: 15, weight: .semibold))
            VStack(spacing: 0) {
                listRow("Figma is not installed", status: "Skipped", first: true)
                listRow("Folder ~/dev/old-app was moved", status: "Locate…", link: true)
                listRow("Xcode is fullscreen", status: "Skipped")
                listRow("Stage Manager is on", status: "Windows not grouped")
            }
            .padding(.horizontal, 12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.08), lineWidth: 1))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button("View Report") { appState.showingRestoreReport = appState.lastReport != nil }
                    .buttonStyle(WispToolbarPrimaryStyle())
                Button("Undo Restore") { appState.undoRestore() }
                    .buttonStyle(WispToolbarSecondaryStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: 0xF6F6F8))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private var offlineCard: some View {
        card(icon: "display", tint: 0x4A2FC4, tileFill: 0xECE8FD,
             title: "An external display was disconnected",
             message: "Windows from that display were moved onto this screen by macOS. Switch the project to its laptop layout, or reconnect the display and restore the desk layout.") {
            Button("Open Displays") { appState.selectedNav = .displays }
                .buttonStyle(WispToolbarSecondaryStyle())
        }
    }
    
    private var seatsCard: some View {
        card(icon: "rectangle.on.rectangle", tint: 0x3A3A3C, tileFill: 0xECECEF,
             title: "Window previews are off",
             message: "WispTile draws simple outlines instead of real window pictures. Turn on Screen Recording for WispTile to see real previews; pictures stay on this Mac.") {
            Button("Allow Previews…") { WindowShots.requestAccess() }
                .buttonStyle(WispToolbarSecondaryStyle())
        }
    }
    
    // MARK: Pieces
    private func card<B: View>(icon: String, tint: UInt, tileFill: UInt, title: String, message: String, @ViewBuilder buttons: () -> B) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: tint))
                .frame(width: 28, height: 28)
                .background(Color(hex: tileFill))
                .cornerRadius(7)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 14)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x6E6E73))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Spacer(minLength: 16)
            HStack(spacing: 8) { buttons() }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: 0xF6F6F8))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private func listRow(_ text: String, status: String, link: Bool = false, first: Bool = false) -> some View {
        HStack {
            Text(text).font(.system(size: 13)).lineLimit(1)
            Spacer()
            Text(status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(link ? Color(hex: 0x4A2FC4) : Color(hex: 0x8A4B05))
        }
        .frame(height: 40)
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }

}
