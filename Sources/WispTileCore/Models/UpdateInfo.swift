import Foundation

public enum UpdateCategory: String, Codable, Equatable, Sendable {
    case new = "NEW"
    case improved = "IMPROVED"
    case fixed = "FIXED"
}

public struct ReleaseNoteItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let category: UpdateCategory
    public let text: String
    
    public init(id: String = UUID().uuidString, category: UpdateCategory, text: String) {
        self.id = id
        self.category = category
        self.text = text
    }
}

public struct UpdateInfo: Codable, Equatable, Sendable {
    public let version: String
    public let currentVersion: String
    public let releaseDate: Date
    public let fileSizeMB: Double
    public let downloadURL: URL?
    public let releaseNotes: [ReleaseNoteItem]
    public let summary: String
    public let isCritical: Bool
    
    public init(
        version: String,
        currentVersion: String,
        releaseDate: Date,
        fileSizeMB: Double,
        downloadURL: URL? = nil,
        releaseNotes: [ReleaseNoteItem],
        summary: String,
        isCritical: Bool = false
    ) {
        self.version = version
        self.currentVersion = currentVersion
        self.releaseDate = releaseDate
        self.fileSizeMB = fileSizeMB
        self.downloadURL = downloadURL
        self.releaseNotes = releaseNotes
        self.summary = summary
        self.isCritical = isCritical
    }
    
    public static var sample1_4: UpdateInfo {
        UpdateInfo(
            version: "1.4",
            currentVersion: "1.3.2",
            releaseDate: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4)) ?? Date(),
            fileSizeMB: 18.4,
            downloadURL: AppLinks.releases,
            releaseNotes: [
                ReleaseNoteItem(category: .new, text: "Custom tiling templates: draw your own zones and save them."),
                ReleaseNoteItem(category: .new, text: "Create a project from your open windows in one click from the menu bar."),
                ReleaseNoteItem(category: .improved, text: "Workspace drift is detected faster after a display is connected."),
                ReleaseNoteItem(category: .improved, text: "Restore reports now explain why a step failed."),
                ReleaseNoteItem(category: .fixed, text: "Chrome tabs sometimes opened in the wrong profile.")
            ],
            summary: "Custom tiling templates and one-click project creation."
        )
    }
}

public struct UpdateSettings: Codable, Equatable, Sendable {
    public var automaticallyCheckForUpdates: Bool
    public var notifyWhenAppIsClosed: Bool
    public var automaticallyInstallUpdates: Bool
    
    public init(
        automaticallyCheckForUpdates: Bool = true,
        notifyWhenAppIsClosed: Bool = true,
        automaticallyInstallUpdates: Bool = false
    ) {
        self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
        self.notifyWhenAppIsClosed = notifyWhenAppIsClosed
        self.automaticallyInstallUpdates = automaticallyInstallUpdates
    }
    
    public static let `default` = UpdateSettings()
}
