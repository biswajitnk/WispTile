import SwiftUI
import AppKit
import WispTileCore

public struct DiagnosticsExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bundle: DiagnosticsBundle = DiagnosticsEngine.shared.generateBundle()
    @State private var copied: Bool = false
    @State private var exportedPath: String?
    @State private var showingExportAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Diagnostics & Health")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WispColors.textPrimary)
                    Text("Sanitized diagnostic bundle to help debug display or window issues")
                        .font(.system(size: 12))
                        .foregroundColor(WispColors.textSecondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Diagnostics Sheet")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Privacy Banner
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(WispColors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy & Security Guaranteed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WispColors.textPrimary)
                    Text("Window contents, file data, and credentials are never collected. Personal usernames and emails are fully redacted.")
                        .font(.system(size: 11))
                        .foregroundColor(WispColors.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .background(WispColors.accent.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            
            // Diagnostics Content
            ScrollView {
                VStack(spacing: 16) {
                    // System & Health Stats
                    HStack(spacing: 16) {
                        statCard(
                            title: "Crash-Free Rate",
                            value: String(format: "%.1f%%", bundle.healthStats.crashFreeSessionRate),
                            icon: "checkmark.seal.fill",
                            color: WispColors.statusSuccess
                        )
                        statCard(
                            title: "Sessions Tracked",
                            value: "\(bundle.healthStats.totalSessions)",
                            icon: "chart.bar.fill",
                            color: WispColors.accent
                        )
                        statCard(
                            title: "Displays Connected",
                            value: "\(bundle.displays.count)",
                            icon: "display",
                            color: Color.blue
                        )
                    }
                    
                    // Hardware & Displays
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Topology")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WispColors.textSecondary)
                        
                        VStack(spacing: 0) {
                            ForEach(bundle.displays, id: \.id) { disp in
                                HStack {
                                    Image(systemName: disp.hasNotch ? "laptopcomputer" : "display")
                                        .foregroundColor(WispColors.textSecondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(disp.name)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("\(disp.resolution) · \(disp.hasNotch ? "Notch Safe Area: \(Int(disp.safeAreaTopInset))pt" : "No Notch")")
                                            .font(.system(size: 11))
                                            .foregroundColor(WispColors.textSecondary)
                                    }
                                    Spacer()
                                    if disp.isPrimary {
                                        Text("Primary")
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.06))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                if disp.id != bundle.displays.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    }
                    
                    // Sanitized Logs
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sanitized Event Log")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(WispColors.textSecondary)
                            Spacer()
                            Text("\(bundle.sanitizedLogEntries.count) events")
                                .font(.system(size: 11))
                                .foregroundColor(WispColors.textSecondary)
                        }
                        
                        ScrollView(.vertical) {
                            Text(bundle.sanitizedLogEntries.joined(separator: "\n"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: 0x2C2C2E))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(height: 140)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            
            Divider()
            
            // Footer actions
            HStack(spacing: 12) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bundle.formattedSummaryText, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied to Clipboard" : "Copy Summary")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color.white)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy diagnostic summary to clipboard")
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .frame(height: 32)
                
                Button(action: {
                    if let url = try? DiagnosticsEngine.shared.exportBundleToFile() {
                        exportedPath = url.path
                        showingExportAlert = true
                    }
                }) {
                    Text("Export JSON File…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(WispColors.accent)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Export diagnostic report to JSON file")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(hex: 0xF9F9FB))
        }
        .frame(width: 620, height: 600)
        .background(Color(hex: 0xF5F5F7))
        .alert("Diagnostics Exported", isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sanitized diagnostic bundle saved to:\n\(exportedPath ?? "")")
        }
    }
    
    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(WispColors.textSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WispColors.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 1))
    }
}
