import SwiftUI
import WispTileCore

public struct QuickSwitcherOverlay: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    
    public init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(WispColors.accent)
                    .font(.system(size: 16))
                
                TextField("Switch project or action… (⌃⌥1–9)", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                
                Button("Esc") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(WispColors.textSecondary)
            }
            .padding(16)
            .background(Color.white)
            
            Divider().background(WispColors.divider)
            
            // Filtered Projects List
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(filteredProjects) { project in
                        projectRow(for: project)
                    }
                    
                    // Quick Action: Capture
                    Button(action: {
                        isPresented = false
                        appState.showingCaptureSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(WispColors.accent.opacity(0.12))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(WispColors.accent)
                                )
                            
                            Text("Capture Current Desktop")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(WispColors.textPrimary)
                            
                            Spacer()
                            
                            WispBadge(text: appState.settings.captureShortcut, color: Color.gray)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
        }
        .frame(width: 520, height: 320)
        .background(WispColors.canvas)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(WispColors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
    
    private var filteredProjects: [Project] {
        if searchText.isEmpty { return appState.projects }
        return appState.projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        let initial = String(project.name.prefix(1)).uppercased()
        
        Button(action: {
            appState.selectProject(project)
            isPresented = false
            Task {
                await appState.executeRestore(for: project)
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text(initial)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WispColors.textPrimary)
                
                Spacer()
                
                if let shortcut = appState.displayShortcut(for: project) {
                    WispBadge(text: shortcut, color: WispColors.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.8))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
