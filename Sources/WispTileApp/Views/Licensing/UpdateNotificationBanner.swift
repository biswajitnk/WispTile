import SwiftUI
import WispTileCore

public struct UpdateNotificationBanner: View {
    @ObservedObject var appState: AppState
    let update: UpdateInfo
    let onUpdateNow: () -> Void
    let onDismiss: () -> Void
    let onWhatsNew: () -> Void
    
    public init(
        appState: AppState,
        update: UpdateInfo,
        onUpdateNow: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onWhatsNew: @escaping () -> Void
    ) {
        self.appState = appState
        self.update = update
        self.onUpdateNow = onUpdateNow
        self.onDismiss = onDismiss
        self.onWhatsNew = onWhatsNew
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                WispLogoView(size: 18, cornerRadius: 5)
                
                Text("WISPTILE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: 0x6E6E73))
                
                Spacer()
                
                Text("now")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x6E6E73))
            }
            
            // Title & Subtitle
            Text("WispTile \(update.version) is available")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WispColors.textPrimary)
                .padding(.top, 10)
            
            Text("\(update.summary) You have \(update.currentVersion).")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x3A3A3C))
                .padding(.top, 3)
            
            // Buttons
            HStack(spacing: 8) {
                Button(action: onUpdateNow) {
                    Text("Update Now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(WispColors.accent)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                
                Button(action: onDismiss) {
                    Text("Later")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WispColors.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(Color.white)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onWhatsNew) {
                    Text("What’s New")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WispColors.accent)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(14)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: 0xF5F5F7).opacity(0.96))
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}
