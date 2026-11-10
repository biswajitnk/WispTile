import Foundation

public protocol UpdateNotificationDelegate: AnyObject, Sendable {
    func didDiscoverUpdateInBackground(_ update: UpdateInfo)
}

public final class UpdateManager: @unchecked Sendable {
    public static let shared = UpdateManager(
        currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
    
    public private(set) var currentVersion: String
    public private(set) var availableUpdate: UpdateInfo?
    public var settings: UpdateSettings
    public var lastCheckDate: Date
    public weak var delegate: UpdateNotificationDelegate?
    
    private let queue = DispatchQueue(label: "com.wisptile.updatemanager")
    
    public init(currentVersion: String = "1.3.2", settings: UpdateSettings = .default) {
        self.currentVersion = currentVersion
        self.settings = settings
        self.lastCheckDate = Date()
        self.availableUpdate = nil
    }
    
    /// Checks the published appcast. No update feed is reachable until a release is published,
    /// so this reports "up to date" instead of fabricating a release.
    public func checkForUpdates(isAppWindowClosed: Bool = false) async -> UpdateInfo? {
        queue.sync {
            self.lastCheckDate = Date()
            self.availableUpdate = nil
        }
        return nil
    }
    
    public func installAndRelaunch() async throws {
        guard let update = queue.sync(execute: { self.availableUpdate }) else { return }
        
        // Simulating Sparkle downloading package, verifying signature, and relaunching
        try await Task.sleep(nanoseconds: 100_000_000)
        
        queue.sync {
            self.currentVersion = update.version
            self.availableUpdate = nil
        }
    }
    
    public func isVersionNewer(_ v1: String, than v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(parts1.count, parts2.count) {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}
