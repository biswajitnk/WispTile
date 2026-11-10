import XCTest
import CoreGraphics
@testable import WispTileCore

/// Behaviour checks for capture → restore, window matching and tiling spacing.
@MainActor
final class RecallBehaviorTests: XCTestCase {

    /// A 1440 × 900 laptop screen with a 25 pt menu bar, in AX (top-left) coordinates.
    private let laptop = DisplayInfo(
        id: 1, name: "Built-in", isPrimary: true, isBuiltIn: true, hasNotch: false, safeAreaTopInset: 0,
        cocoaFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        cocoaVisibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875),
        axFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        axVisibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875))

    private func window(_ id: CGWindowID, _ app: String, _ bundle: String, standard: Bool = true) -> WindowModel {
        WindowModel(id: id, pid: 1, appName: app, bundleId: bundle, title: "", frame: .zero,
                    isMinimized: false, isStandardWindow: standard, axElement: nil)
    }

    // MARK: Capture → restore puts windows back exactly

    func testCapturedWindowRestoresToItsExactFrame() {
        let original = CGRect(x: 100, y: 125, width: 700, height: 500)
        let rel = CaptureEngine.relativeRect(of: original, in: laptop.axVisibleFrame)
        let item = ProjectItem(appName: "Safari", bundleId: "com.apple.Safari", zoneId: "zone_1", customRelativeRect: rel)
        let layout = ProjectLayout(displaySignature: DisplaySignature(screenCount: 1, resolutions: [CGSize(width: 1440, height: 900)]),
                                   displayZones: [0: [Zone(id: "zone_1", name: "Safari", relativeRect: rel)]])
        let frame = TilingEngine.shared.restoreFrame(for: item, layout: layout, on: laptop).frame
        XCTAssertEqual(frame.minX, original.minX, accuracy: 1)
        XCTAssertEqual(frame.minY, original.minY, accuracy: 1)
        XCTAssertEqual(frame.width, original.width, accuracy: 1)
        XCTAssertEqual(frame.height, original.height, accuracy: 1)
    }

    func testRepeatedCaptureAndRestoreDoesNotShrinkWindows() {
        var frame = CGRect(x: 0, y: 25, width: 1440, height: 875) // a full-screen window
        for _ in 0..<5 {
            let rel = CaptureEngine.relativeRect(of: frame, in: laptop.axVisibleFrame)
            let item = ProjectItem(appName: "Code", bundleId: "com.microsoft.VSCode", customRelativeRect: rel)
            frame = TilingEngine.shared.restoreFrame(for: item, layout: nil, on: laptop).frame
        }
        XCTAssertEqual(frame.width, 1440, accuracy: 1)
        XCTAssertEqual(frame.height, 875, accuracy: 1)
    }

    func testTemplateZonesStayInsideTheUsableArea() {
        let item = ProjectItem(appName: "Notes", bundleId: "com.apple.Notes", zoneId: "2")
        let layout = ProjectLayout(displaySignature: DisplaySignature(screenCount: 1, resolutions: [CGSize(width: 1440, height: 900)]),
                                   displayZones: [0: Template.mainAndStack.zones])
        let frame = TilingEngine.shared.restoreFrame(for: item, layout: layout, on: laptop).frame
        XCTAssertTrue(laptop.axVisibleFrame.contains(frame), "\(frame) should sit inside the usable area")
        XCTAssertGreaterThan(frame.minX, laptop.axVisibleFrame.midX - 1, "Main + Stack zone 2 is on the right")
    }

    // MARK: Each saved item gets its own window

    func testTwoItemsOfTheSameAppUseDifferentWindows() {
        let first = ProjectItem(appName: "Safari", bundleId: "com.apple.Safari")
        let second = ProjectItem(appName: "Safari", bundleId: "com.apple.Safari")
        let windows = [window(10, "Safari", "com.apple.Safari"), window(11, "Safari", "com.apple.Safari")]
        var claimed = Set<CGWindowID>()
        let a = RestoreEngine.pickWindow(for: first, in: windows, claimed: claimed, preferNotIn: nil)
        claimed.insert(a!.id)
        let b = RestoreEngine.pickWindow(for: second, in: windows, claimed: claimed, preferNotIn: nil)
        XCTAssertEqual(a?.id, 10)
        XCTAssertEqual(b?.id, 11)
    }

    func testNewlyOpenedWindowIsPreferredOverAnOldOne() {
        let item = ProjectItem(appName: "Finder", bundleId: "com.apple.finder", pathOrURL: "~/dev")
        let windows = [window(1, "Finder", "com.apple.finder"), window(2, "Finder", "com.apple.finder")]
        let picked = RestoreEngine.pickWindow(for: item, in: windows, claimed: [], preferNotIn: [1])
        XCTAssertEqual(picked?.id, 2)
    }

    func testNonStandardAndClaimedWindowsAreNeverPicked() {
        let item = ProjectItem(appName: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let windows = [window(5, "Slack", "com.tinyspeck.slackmacgap", standard: false),
                       window(6, "Slack", "com.tinyspeck.slackmacgap")]
        XCTAssertNil(RestoreEngine.pickWindow(for: item, in: windows, claimed: [6], preferNotIn: nil))
    }

    // MARK: Excluded apps

    func testExcludedAppsMatchByNameOrBundle() {
        var ex = ExcludedApps()
        ex.appNames.insert("Figma")
        ex.bundleIds.insert("com.example.tool")
        XCTAssertTrue(ex.isExcluded(bundleId: nil, appName: "Figma"))
        XCTAssertTrue(ex.isExcluded(bundleId: "com.example.tool", appName: "Tool"))
        XCTAssertFalse(ex.isExcluded(bundleId: "com.apple.Safari", appName: "Safari"))
    }
    
    // MARK: Projects arranged with a layout template
    
    func testOldSavedProjectsStillLoadWithoutLayoutFields() throws {
        let project = Project(name: "Old", items: [ProjectItem(appName: "Notes", bundleId: "com.apple.Notes")])
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as! [String: Any]
        json.removeValue(forKey: "layoutTemplateId")
        var items = json["items"] as! [[String: Any]]
        items[0].removeValue(forKey: "templateZoneId")
        json["items"] = items
        let decoded = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.layoutTemplateId)
        XCTAssertNil(decoded.items[0].templateZoneId)
        XCTAssertEqual(decoded.name, "Old")
    }
    
    func testAppsUseTheirChosenZoneOrFollowListOrder() {
        let t = Template.thirds
        var chosen = ProjectItem(appName: "Safari", bundleId: "com.apple.Safari")
        chosen.templateZoneId = t.zones[2].id
        XCTAssertEqual(TilingEngine.zone(for: chosen, index: 0, in: t)?.id, t.zones[2].id)
        let byOrder = ProjectItem(appName: "Notes", bundleId: "com.apple.Notes")
        XCTAssertEqual(TilingEngine.zone(for: byOrder, index: 1, in: t)?.id, t.zones[1].id)
        XCTAssertEqual(TilingEngine.zone(for: byOrder, index: 9, in: t)?.id, t.zones[2].id, "extra apps stack in the last zone")
    }
    
    func testArrangedProjectRestoresIntoTheTemplateZone() {
        let t = Template.halves
        var item = ProjectItem(appName: "Safari", bundleId: "com.apple.Safari",
                               customRelativeRect: CGRect(x: 0, y: 0, width: 1, height: 1)) // captured full screen
        item.templateZoneId = t.zones[1].id // but arranged into the right half
        let frame = TilingEngine.shared.restoreFrame(for: item, layout: nil, on: laptop, template: t, index: 0).frame
        XCTAssertGreaterThanOrEqual(frame.minX, laptop.axVisibleFrame.midX - 1)
        XCTAssertTrue(laptop.axVisibleFrame.contains(frame))
    }
    
    // MARK: Tile Now zone order matches the Layouts preview
    
    func testTilingKeepsTheCurrentLeftToRightOrder() {
        // Photos is on the right, App Store on the left, Ulaa in the middle.
        let zones = TilingEngine.assignZones(apps: ["Photos", "App Store", "Ulaa"], minX: [900, 10, 400],
                                             template: .thirds, choices: [:])
        XCTAssertEqual(zones, [2, 0, 1])
    }
    
    func testChosenZonesWinAndOthersFillTheRest() {
        let t = Template.thirds
        let zones = TilingEngine.assignZones(apps: ["Photos", "App Store", "Ulaa"], minX: [0, 10, 20],
                                             template: t, choices: ["Photos": t.zones[2].id])
        XCTAssertEqual(zones, [2, 0, 1], "Photos goes to its chosen zone 3; the others fill zones 1 and 2 left to right")
    }
    
    func testExtraWindowsStackInTheLastZone() {
        let zones = TilingEngine.assignZones(apps: ["A", "B", "C"], minX: [0, 1, 2], template: .halves, choices: [:])
        XCTAssertEqual(zones, [0, 1, 1])
    }
}
