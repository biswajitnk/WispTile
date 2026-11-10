import SwiftUI
import AppKit
import WispTileCore

public struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var selectedOption = 1

    public init(appState: AppState, isPresented: Binding<Bool>) { self.appState = appState; self._isPresented = isPresented }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                WispLogoView(size: 64, cornerRadius: 15)
                Text("Welcome to WispTile").font(.system(size: 24, weight: .bold)).foregroundColor(WispColors.textPrimary).padding(.top, 18)
                Text("How would you like to start?").font(.system(size: 14)).foregroundColor(WispColors.textSecondary).padding(.top, 6)
                HStack(spacing: 16) {
                    option(0, title: "Just tile my windows", detail: "Snap windows into zones and keep them tidy. You can add projects later.", project: false)
                    option(1, title: "Set up a project", detail: "Save what is open right now as a project, then bring it back with one shortcut.", project: true)
                }.padding(.top, 26)
                Button("Skip setup for now") { appState.completeOnboarding(); isPresented = false }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(WispColors.textSecondary).padding(.top, 16)
                Spacer()
            }.padding(.horizontal, 48).padding(.top, 20)
            OnboardingFooter(step: 0, label: "1 of 4") { EmptyView() } trailing: {
                Button("Continue") { isPresented = false; appState.showingPermissionGuide = true }.buttonStyle(OnboardingPrimaryButtonStyle())
            }
        }.frame(width: 720, height: 560).background(WispColors.canvas).onboardingWindowChrome(width: 720, height: 560)
    }

    private func option(_ index: Int, title: String, detail: String, project: Bool) -> some View {
        let selected = selectedOption == index
        return Button { selectedOption = index } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0x2A3070))
                    if project { HStack(spacing: 5) { miniWindow(68, 54); VStack(spacing: 5) { miniWindow(55, 24); miniWindow(55, 25) } } }
                    else { HStack(spacing: 5) { miniWindow(62, 55); miniWindow(62, 55) } }
                }.frame(height: 96)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(WispColors.textPrimary).padding(.top, 12)
                Text(detail).font(.system(size: 12)).foregroundColor(WispColors.textSecondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.top, 5)
            }.padding(selected ? 13 : 14).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color(hex: 0x5B3CE0) : WispColors.border, lineWidth: selected ? 2 : 1))
                .shadow(color: selected ? Color(hex: 0x5B3CE0).opacity(0.16) : .black.opacity(0.04), radius: selected ? 8 : 2, y: 2)
        }.buttonStyle(.plain)
    }
    private func miniWindow(_ width: CGFloat, _ height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.93)).frame(width: width, height: height)
            .overlay(VStack { HStack(spacing: 3) { Circle().fill(Color.red.opacity(0.8)).frame(width: 4, height: 4); Circle().fill(Color.yellow.opacity(0.9)).frame(width: 4, height: 4); Spacer() }.padding(5); Spacer() })
    }
}

private struct OnboardingWindowChrome: NSViewRepresentable {
    let width: CGFloat, height: CGFloat
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.formUnion([.titled, .closable, .miniaturizable])
            window.styleMask.subtract([.resizable, .fullScreen])
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: width, height: height))
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }
}

struct MainWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            MainWindowChrome.apply(to: window)
        }
    }
    
    /// Shared sidebar design: a transparent 52 pt title bar, so the traffic lights sit centred in
    /// the sidebar's top band and on the same row as each screen's 52 pt toolbar.
    static func apply(to window: NSWindow) {
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        if window.toolbar == nil {
            let toolbar = NSToolbar(identifier: "WispTileMainWindow")
            toolbar.showsBaselineSeparator = false
            window.toolbar = toolbar
        }
        window.toolbarStyle = .unified
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = NSSize(width: 820, height: 560)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }
}

public extension View {
    func onboardingWindowChrome(width: CGFloat, height: CGFloat) -> some View {
        background(OnboardingWindowChrome(width: width, height: height))
    }

    func mainWindowChrome() -> some View {
        background(MainWindowChrome())
    }
}

public struct OnboardingPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 13, weight: .medium)).foregroundColor(.white).padding(.horizontal, 14).frame(height: 30).background(Color(hex: 0x5B3CE0)).cornerRadius(7).opacity(configuration.isPressed ? 0.8 : 1) }
}

public struct OnboardingFooter<Leading: View, Trailing: View>: View {
    let step: Int, label: String, leading: Leading, trailing: Trailing
    public init(step: Int, label: String, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) { self.step = step; self.label = label; self.leading = leading(); self.trailing = trailing() }
    public var body: some View {
        HStack {
            HStack(spacing: 10) { HStack(spacing: 5) { ForEach(0..<4) { i in Capsule().fill(i == step ? Color(hex: 0x5B3CE0) : Color.black.opacity(0.12)).frame(width: i == step ? 14 : 6, height: 6) } }; Text(label).font(.system(size: 11)).foregroundColor(WispColors.textSecondary) }.frame(width: 150, alignment: .leading)
            Spacer(); leading; trailing
        }.padding(.top, 16).padding(.horizontal, 28).padding(.bottom, 22)
    }
}
