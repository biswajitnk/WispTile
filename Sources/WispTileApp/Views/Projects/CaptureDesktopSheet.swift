import SwiftUI
import WispTileCore

public struct CaptureDesktopSheet: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    
    @State private var projectName: String = "Untitled Project"
    @State private var shortcut: String = ""
    @State private var capturedWindows: [CapturedWindow] = []
    @State private var spacesMode: SpacesMode = .currentSpace
    @State private var offDesktop = 0
    
    public init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        self._isPresented = isPresented
    }
    
    private var selectedCount: Int { capturedWindows.filter { $0.isSelected }.count }
    
    private func displayName(_ index: Int) -> String {
        guard appState.displays.indices.contains(index) else { return "Display \(index + 1)" }
        let d = appState.displays[index]
        return d.isBuiltIn ? "Built-in" : d.name
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Title bar
            ZStack {
                Text("Capture Current Desktop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WispColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1), alignment: .bottom)
            
            VStack(alignment: .leading, spacing: 14) {
                // Name + display pills
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Project name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WispColors.textSecondary)
                        TextField("Untitled Project", text: $projectName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Color.white)
                            .cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.14), lineWidth: 1))
                    }
                    HStack(spacing: 6) {
                        ForEach(appState.displays.indices, id: \.self) { idx in
                            let d = appState.displays[idx]
                            Text("\(d.isBuiltIn ? "Built-in" : d.name) · \(Int(d.cocoaFrame.width)) × \(Int(d.cocoaFrame.height))")
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.black.opacity(0.10), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 2)
                }
                
                // Count line
                HStack {
                    Text("\(capturedWindows.count) window\(capturedWindows.count == 1 ? "" : "s") on this desktop"
                         + (offDesktop > 0 ? " · \(offDesktop) more on other desktops or minimized" : ""))
                    Spacer()
                    Text("\(selectedCount) selected").fontWeight(.medium)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WispColors.textSecondary)
                
                // Window list
                ScrollView {
                    VStack(spacing: 0) {
                        if capturedWindows.isEmpty {
                            Text("No windows found. Open the apps you want in this project, then try again.")
                                .font(.system(size: 12))
                                .foregroundColor(WispColors.textSecondary)
                                .padding(.vertical, 28)
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(capturedWindows.indices, id: \.self) { i in
                            windowRow(i)
                            if i != capturedWindows.count - 1 {
                                Divider().background(Color.black.opacity(0.07))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
                    .padding(1)
                }
                .frame(maxHeight: CGFloat(max(1, capturedWindows.count)) * 49 + (capturedWindows.isEmpty ? 40 : 4))
                
                // Spaces
                HStack {
                    HStack(spacing: 6) {
                        Text("Spaces").font(.system(size: 13))
                        Text("Where windows are put back")
                            .font(.system(size: 12))
                            .foregroundColor(WispColors.textSecondary)
                    }
                    Spacer()
                    WispSegmented(selection: Binding(
                        get: { spacesMode == .currentSpace ? 0 : 1 },
                        set: { spacesMode = $0 == 0 ? .currentSpace : .originalSpaces }
                    ), options: ["Current Space", "Original Spaces"])
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 0.5)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer(minLength: 0)
            
            // Footer
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(WispToolbarSecondaryStyle())
                Button("Create Project", action: createProject)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(WispToolbarPrimaryStyle())
                    .disabled(selectedCount == 0)
                    .opacity(selectedCount == 0 ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            .frame(height: 60)
        }
        .frame(minWidth: 640, idealWidth: 820, minHeight: 480, idealHeight: 620)
        .background(WispColors.canvas)
        .onAppear {
            let taken = Set(appState.projects.compactMap { $0.shortcut })
            self.shortcut = (1...9).map { "⌥\($0)" }.first(where: { !taken.contains($0) }) ?? ""
            let (windows, _) = CaptureEngine.shared.scanDesktop()
            self.capturedWindows = windows
            self.offDesktop = WindowManager.shared.countWindowsOffCurrentDesktop()
        }
    }
    
    private func windowRow(_ i: Int) -> some View {
        let w = capturedWindows[i]
        let locked = w.isCallApp
        return HStack(spacing: 12) {
            Button {
                if !locked { capturedWindows[i].isSelected.toggle() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(w.isSelected ? WispColors.accent : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(w.isSelected ? Color.clear : Color(hex: 0xB0B0B5), lineWidth: 1.5))
                    if w.isSelected {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("Include \(w.appName)")
            
            AppIconView(bundleId: w.bundleId, appName: w.appName, pid: w.pid, size: 28)
                .opacity(locked ? 0.5 : 1)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(w.appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(locked ? WispColors.textSecondary : WispColors.textPrimary)
                    .lineLimit(1)
                if let path = w.detectedPathOrURL {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(WispColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if locked {
                    Text("Call app, left out by your rules")
                        .font(.system(size: 11))
                        .foregroundColor(WispColors.textSecondary)
                } else {
                    Text("Window position only")
                        .font(.system(size: 11))
                        .foregroundColor(WispColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(displayName(w.displayIndex))
                .font(.system(size: 12))
                .foregroundColor(WispColors.textSecondary)
        }
        .frame(height: 48)
    }
    
    private func createProject() {
        let selected = capturedWindows.filter { $0.isSelected }
        var project = CaptureEngine.shared.captureProject(
            name: projectName.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Project" : projectName,
            shortcut: shortcut.isEmpty ? nil : shortcut,
            selectedWindows: selected
        )
        project.restoreOptions.spacesMode = spacesMode
        appState.saveProject(project)
        // Store a real screenshot of every captured window, then refresh the saved preview image.
        let ids = selected.map { $0.id }
        let saved = project
        Task {
            let shots = await WindowShots.capture(windowIDs: ids)
            for (i, w) in selected.enumerated() where i < saved.items.count {
                if let img = shots[w.id], let png = WindowShots.png(img) {
                    StorageEngine.shared.saveItemShot(png, project: saved.id, item: saved.items[i].id)
                }
            }
            LayoutPreviewStore.save(project: saved)
            appState.objectWillChange.send()
        }
        isPresented = false
    }
}
