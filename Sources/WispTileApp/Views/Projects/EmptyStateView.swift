import SwiftUI
import WispTileCore

public struct EmptyStateView: View {
    @ObservedObject var appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 52)
            .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    WispLogoView(size: 64, cornerRadius: 16)
                
                    Text("No projects yet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                
                    Text("Arrange your windows the way you work, then capture them. Next time, one shortcut puts everything back.")
                        .font(.system(size: 13))
                        .foregroundColor(WispColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 420)
                }
            
                HStack(spacing: 8) {
                Button("Capture Current Desktop") {
                    appState.showingCaptureSheet = true
                }
                .buttonStyle(WispPrimaryButtonStyle())
                
                Button("Start With a Layout") {
                    appState.selectedNav = .layouts
                }
                .buttonStyle(WispSecondaryButtonStyle())
            }
            
                HStack(spacing: 16) {
                stepCard(
                    number: "1",
                    title: "Open your apps",
                    description: "Set up files, tabs and folders as you like."
                )
                stepCard(
                    number: "2",
                    title: "Capture",
                    description: "Press ⌃⌥C. Choose what to include."
                )
                stepCard(
                    number: "3",
                    title: "Switch any time",
                    description: "Use ⌃⌥1 to ⌃⌥9 from anywhere."
                )
            }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
    }
    
    private func stepCard(number: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(number)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WispColors.accent)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WispColors.textPrimary)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(WispColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .wispCard(cornerRadius: 12, padding: 14)
    }
}
