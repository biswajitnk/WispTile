import SwiftUI
import WispTileCore

public struct SnapshotsView: View {
    @ObservedObject var appState: AppState
    @State private var showingTakeSnapshotSheet: Bool = false
    @State private var newSnapshotName: String = ""
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar matching Board 16
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Snapshots")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                    Text("Saved before every restore, kept for 30 days")
                        .font(.system(size: 11))
                        .foregroundColor(WispColors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    let defaultName = "Manual Snapshot \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))"
                    appState.takeSnapshot(name: defaultName)
                }) {
                    Text("Take Snapshot")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Color(hex: 0x5B3CE0))
                        .cornerRadius(7)
                        .shadow(color: Color.black.opacity(0.18), radius: 1, y: 0.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take manual snapshot of current windows")
            }
            .padding(.leading, 24)
            .padding(.trailing, 20)
            .frame(height: 52)
            .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.snapshots.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                            ForEach(appState.snapshots) { snapshot in
                                snapshotCard(snapshot)
                            }
                        }
                    }
                    
                    Text("A snapshot remembers where every window was. Restoring one moves windows back; it does not reopen closed apps.")
                        .font(.system(size: 12))
                        .foregroundColor(WispColors.textSecondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .background(Color(hex: 0xF5F5F7))
    }
    
    private func thumbnailItems(_ snapshot: Snapshot) -> [CanvasItem] {
        let base = snapshot.displaySignature.resolutions.first ?? CGSize(width: 1440, height: 900)
        let bounds = snapshot.windows.reduce(CGRect(origin: .zero, size: base)) { $0.union($1.frame) }
        guard bounds.width > 0, bounds.height > 0 else { return [] }
        return snapshot.windows.prefix(12).enumerated().map { i, w in
            CanvasItem(id: "\(i)-\(w.windowId)", appName: w.appName, bundleId: w.bundleId, pid: nil, detail: nil,
                       rect: CGRect(x: (w.frame.minX - bounds.minX) / bounds.width, y: (w.frame.minY - bounds.minY) / bounds.height,
                                    width: w.frame.width / bounds.width, height: w.frame.height / bounds.height))
        }
    }
    
    @ViewBuilder
    private func snapshotCard(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 10) {
            // Thumbnail: every saved window drawn where it was on screen
            LayoutCanvasView(items: thumbnailItems(snapshot), gap: 1.5, compact: true, fills: true)
                .frame(height: 128)
            
            // Meta info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("\(formattedDate(snapshot.timestamp)) · \(snapshot.windows.count) window\(snapshot.windows.count == 1 ? "" : "s") · \(snapshot.displaySignature.screenCount) display\(snapshot.displaySignature.screenCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(WispColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(snapshot.kind == .autoBeforeRestore ? "Auto" : "Manual")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: 0x3A3A3C))
            }
            
            // Actions
            HStack(spacing: 8) {
                Button(action: {
                    appState.undoRestore(snapshot: snapshot)
                }) {
                    Text("Restore")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WispColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color.white)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 0.5, y: 0.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restore snapshot \(snapshot.name)")
                
                Button(action: {
                    appState.deleteSnapshot(snapshot)
                }) {
                    Text("Delete")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: 0xB3261E))
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Color.white)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 0.5, y: 0.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete snapshot \(snapshot.name)")
            }
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(WispColors.textSecondary.opacity(0.5))
                .padding(.top, 40)
            
            Text("No Snapshots Yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(WispColors.textPrimary)
            
            Text("WispTile automatically takes a snapshot before every restore so you can undo anytime.")
                .font(.system(size: 13))
                .foregroundColor(WispColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button("Take First Snapshot") {
                appState.takeSnapshot(name: "Initial Desktop State")
            }
            .buttonStyle(WispPrimaryButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return "Today, \(df.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return "Yesterday, \(df.string(from: date))"
        } else {
            let df = DateFormatter()
            df.dateFormat = "d MMM, HH:mm"
            return df.string(from: date)
        }
    }
}
