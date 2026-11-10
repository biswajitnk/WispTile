import Foundation

public final class StorageEngine: @unchecked Sendable {
    public static let shared = StorageEngine()
    
    private let baseDirectory: URL
    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.wisptile.storage", qos: .utility)
    
    public init(customBaseDirectory: URL? = nil) {
        if let custom = customBaseDirectory {
            self.baseDirectory = custom
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("WispTile", isDirectory: true)
        }
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        createDirectoriesIfNeeded()
    }
    
    private var projectsDirectory: URL { baseDirectory.appendingPathComponent("Projects", isDirectory: true) }
    private var templatesDirectory: URL { baseDirectory.appendingPathComponent("Templates", isDirectory: true) }
    private var snapshotsDirectory: URL { baseDirectory.appendingPathComponent("Snapshots", isDirectory: true) }
    private var previewsDirectory: URL { baseDirectory.appendingPathComponent("Previews", isDirectory: true) }
    private var settingsURL: URL { baseDirectory.appendingPathComponent("Settings.json", isDirectory: false) }
    
    private func createDirectoriesIfNeeded() {
        for dir in [projectsDirectory, templatesDirectory, snapshotsDirectory, previewsDirectory] {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Projects
    public func saveProject(_ project: Project) throws {
        let fileURL = projectsDirectory.appendingPathComponent("\(project.id.uuidString).json")
        let data = try jsonEncoder.encode(project)
        try data.write(to: fileURL, options: .atomic)
    }
    
    public func loadProjects() -> [Project] {
        guard let files = try? fileManager.contentsOfDirectory(at: projectsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var projects: [Project] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let project = try? jsonDecoder.decode(Project.self, from: data) {
                projects.append(project)
            }
        }
        return projects.sorted { $0.createdAt > $1.createdAt }
    }
    
    public func loadProject(id: UUID) -> Project? {
        let fileURL = projectsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? jsonDecoder.decode(Project.self, from: data)
    }
    
    public func deleteProject(id: UUID) {
        let fileURL = projectsDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: previewURL(for: id))
        try? fileManager.removeItem(at: previewsDirectory.appendingPathComponent(id.uuidString, isDirectory: true))
    }
    
    // MARK: - Preview images (last captured layout preview, PNG)
    public func previewURL(for id: UUID) -> URL {
        previewsDirectory.appendingPathComponent("\(id.uuidString).png")
    }
    
    public func savePreview(_ png: Data, for id: UUID) {
        try? fileManager.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)
        try? png.write(to: previewURL(for: id), options: .atomic)
    }
    
    // Per-window screenshots captured with the project (Previews/<project>/<item>.png)
    public func itemShotURL(project: UUID, item: UUID) -> URL {
        previewsDirectory.appendingPathComponent(project.uuidString, isDirectory: true).appendingPathComponent("\(item.uuidString).png")
    }
    
    public func saveItemShot(_ png: Data, project: UUID, item: UUID) {
        let url = itemShotURL(project: project, item: item)
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: url, options: .atomic)
    }
    
    public func hasPreview(for id: UUID) -> Bool {
        fileManager.fileExists(atPath: previewURL(for: id).path)
    }
    
    // MARK: - Templates
    public func saveTemplate(_ template: Template) throws {
        let fileURL = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        let data = try jsonEncoder.encode(template)
        try data.write(to: fileURL, options: .atomic)
    }
    
    public func loadTemplates() -> [Template] {
        var templates = Template.builtInPresets
        guard let files = try? fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil) else {
            return templates
        }
        
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let template = try? jsonDecoder.decode(Template.self, from: data) {
                // User template overrides built-in if IDs match
                if let idx = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[idx] = template
                } else {
                    templates.append(template)
                }
            }
        }
        return templates
    }
    
    public func deleteTemplate(id: UUID) {
        let fileURL = templatesDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Snapshots
    public func saveSnapshot(_ snapshot: Snapshot) throws {
        let fileURL = snapshotsDirectory.appendingPathComponent("\(snapshot.id.uuidString).json")
        let data = try jsonEncoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
    
    public func loadSnapshots() -> [Snapshot] {
        guard let files = try? fileManager.contentsOfDirectory(at: snapshotsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var snapshots: [Snapshot] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let snapshot = try? jsonDecoder.decode(Snapshot.self, from: data) {
                snapshots.append(snapshot)
            }
        }
        return snapshots.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func deleteSnapshot(id: UUID) {
        let fileURL = snapshotsDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Cleans up snapshots older than 30 days
    public func cleanupExpiredSnapshots() {
        let snapshots = loadSnapshots()
        for s in snapshots where s.isExpired {
            deleteSnapshot(id: s.id)
        }
    }
    
    // MARK: - Settings
    public func saveSettings(_ settings: WispTileSettings) throws {
        let data = try jsonEncoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }
    
    public func loadSettings() -> WispTileSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? jsonDecoder.decode(WispTileSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    // MARK: - Export
    public struct ExportBundle: Codable, Sendable {
        public let exportDate: Date
        public let version: String
        public let projects: [Project]
        public let templates: [Template]
    }
    
    public func exportProjectsAndTemplates(targetURL: URL? = nil) throws -> URL {
        let projects = loadProjects()
        let templates = loadTemplates()
        let bundle = ExportBundle(exportDate: Date(), version: "1.3.2", projects: projects, templates: templates)
        let data = try jsonEncoder.encode(bundle)
        
        let destinationURL: URL
        if let target = targetURL {
            destinationURL = target
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let dateStr = dateFormatter.string(from: Date())
            let tempDir = fileManager.temporaryDirectory
            destinationURL = tempDir.appendingPathComponent("WispTile-Export-\(dateStr).json")
        }
        
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }
}
