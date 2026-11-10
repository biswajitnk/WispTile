import SwiftUI
import AppKit
import WispTileCore

public struct RestoreReportSheet: View {
    @ObservedObject var appState: AppState
    let report: RestoreReport
    @Binding var isPresented: Bool
    
    public init(appState: AppState, report: RestoreReport, isPresented: Binding<Bool>) {
        self.appState = appState
        self.report = report
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar (Board 9)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Restore Report")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                    Text("\(whenText) · finished in \(String(format: "%.1f", report.duration)) seconds")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x6E6E73))
                }
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(WispToolbarPrimaryStyle())
            }
            .padding(.leading, 24)
            .padding(.trailing, 20)
            .frame(height: 52)
            .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
            
            VStack(alignment: .leading, spacing: 16) {
                // Headline
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(needsAttention ? Color(hex: 0xFFF1D6) : Color(hex: 0x1F7A3D).opacity(0.12))
                        Image(systemName: needsAttention ? "exclamationmark.triangle" : "checkmark")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(needsAttention ? Color(hex: 0x9A5B00) : Color(hex: 0x2A9D4A))
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(WispColors.textPrimary)
                        Text("\(report.successCount) steps restored · \(report.warningCount) need you · \(report.skippedCount) skipped on purpose")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: 0x6E6E73))
                    }
                }
                
                let reportLayout = narrow ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                reportLayout {
                    // Results
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(report.items.indices, id: \.self) { i in
                                resultRow(report.items[i], first: i == 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .wispPanel()
                    
                    // Side
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 8) {
                            statistic(report.successCount, "Restored", Color(hex: 0x1F7A3D))
                            statistic(report.warningCount, "Need you", Color(hex: 0x8A4B05))
                            statistic(report.skippedCount, "Skipped", Color(hex: 0x6E6E73))
                        }
                        .padding(16)
                        .wispPanel()
                        
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let left = max(0, 600 - ctx.date.timeIntervalSince(report.snapshot.timestamp))
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Not what you wanted?")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(WispColors.textPrimary)
                                Text("Put every window back where it was before this restore. Apps that WispTile launched stay open.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: 0x6E6E73))
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button {
                                    appState.undoRestore()
                                    isPresented = false
                                } label: {
                                    Text("Undo Restore")
                                }
                                .buttonStyle(WispToolbarSecondaryStyle(fullWidth: true))
                                .disabled(left <= 0)
                                .accessibilityLabel("Undo restore and return all windows to their previous places")
                                Text(left > 0 ? "Available for \(Int(left) / 60) min \(Int(left) % 60) s" : "Undo is no longer available")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: 0x6E6E73))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .wispPanel()
                        }
                    }
                    .frame(width: narrow ? nil : 280)
                    .frame(maxWidth: narrow ? .infinity : nil)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WispColors.canvas)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { narrow = g.size.width < 760 }
                .onChange(of: g.size.width) { narrow = $0 < 760 }
        })
    }
    
    @State private var narrow = false
    
        private var needsAttention: Bool { report.warningCount > 0 }
    
    private var headline: String {
        let n = report.warningCount
        return n > 0 ? "\(report.projectName) is ready, with \(n) thing\(n == 1 ? "" : "s") to check" : "\(report.projectName) is ready"
    }
    
    private var whenText: String {
        let t = report.snapshot.timestamp
        let time = t.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(t) ? "Today at \(time)" : t.formatted(date: .abbreviated, time: .shortened)
    }
    
    private enum Kind { case ok, warn, error, skipped }
    
    private func kind(_ item: RestoreReportItem) -> Kind {
        switch item.status {
        case "Restored": return .ok
        case "Skipped": return .skipped
        default: return item.detail.hasPrefix("Could not launch") ? .error : .warn
        }
    }
    
    @ViewBuilder
    private func resultRow(_ item: RestoreReportItem, first: Bool) -> some View {
        let k = kind(item)
        HStack(spacing: 12) {
            statusIcon(k)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
                Text(item.detail)
                    .font(.system(size: 12))
                    .foregroundColor(k == .warn ? Color(hex: 0x6B4300) : (k == .error ? Color(hex: 0x8A1C0D) : Color(hex: 0x6E6E73)))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            switch k {
            case .ok:
                Text("Restored").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0x1F7A3D))
            case .skipped:
                Text("Skipped").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0x6E6E73))
            case .warn:
                Button("Show \(item.appName)") { activate(item) }
                    .buttonStyle(WispReportRowButtonStyle())
            case .error:
                Button("Remove from Project") { removeFromProject(item) }
                    .buttonStyle(WispReportRowButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .background(k == .warn ? Color(hex: 0xFFF8EA) : (k == .error ? Color(hex: 0xFDF1EF) : Color.clear))
        .overlay(first ? nil : Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1), alignment: .top)
    }
    
    @ViewBuilder
    private func statusIcon(_ k: Kind) -> some View {
        let (name, color): (String, UInt) = {
            switch k {
            case .ok: return ("checkmark.circle", 0x2A9D4A)
            case .warn: return ("exclamationmark.triangle", 0x9A5B00)
            case .error: return ("xmark.circle", 0xC5301F)
            case .skipped: return ("minus.circle", 0x6E6E73)
            }
        }()
        Image(systemName: name)
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(Color(hex: color))
            .frame(width: 20, height: 20)
    }
    
    private func statistic(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)").font(.system(size: 28, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(Color(hex: 0x6E6E73))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func activate(_ item: RestoreReportItem) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleId }) {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    private func removeFromProject(_ item: RestoreReportItem) {
        guard var project = appState.projects.first(where: { $0.id == report.projectId }) else { return }
        project.items.removeAll { $0.bundleId == item.bundleId && $0.appName == item.appName }
        appState.saveProject(project)
    }
}

/// 28 px action button used inside Restore Report rows.
struct WispReportRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(WispColors.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(configuration.isPressed ? Color(hex: 0xE6E6EB) : Color.white)
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 0.5, y: 0.5)
    }
}
