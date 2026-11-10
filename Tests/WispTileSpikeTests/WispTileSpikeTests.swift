import XCTest
import CoreGraphics
@testable import WispTileSpike

final class WispTileSpikeTests: XCTestCase {
    
    @MainActor
    func testDisplayManagerZoneCalculations() {
        let display = DisplayInfo(
            id: 1,
            name: "Mock 4K Display",
            isPrimary: true,
            isBuiltIn: false,
            hasNotch: false,
            safeAreaTopInset: 0,
            cocoaFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            cocoaVisibleFrame: CGRect(x: 0, y: 80, width: 2560, height: 1335), // dock 80pt, menu bar 25pt
            axFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            axVisibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1335)
        )
        
        // Test Left 50% zone
        let leftZone = DisplayManager.shared.calculateZoneRect(
            on: display,
            relativeRect: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
            gap: 8.0,
            padding: 12.0
        )
        
        // Expected usable width: 2560 - 24 = 2536.
        // Left zone takes (2536 - 8)/2 = 1264.
        XCTAssertEqual(leftZone.origin.x, 12.0)
        XCTAssertEqual(leftZone.origin.y, 37.0) // 25 (menu bar) + 12 (padding)
        XCTAssertEqual(leftZone.size.width, 1264.0)
        XCTAssertEqual(leftZone.size.height, 1311.0) // 1335 - 24 (padding)
        
        // Test Right Top 25% zone
        let rightTopZone = DisplayManager.shared.calculateZoneRect(
            on: display,
            relativeRect: CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5),
            gap: 8.0,
            padding: 12.0
        )
        
        // Starts at x: 12 + 1264 + 8 = 1284
        XCTAssertEqual(rightTopZone.origin.x, 1284.0)
        XCTAssertEqual(rightTopZone.origin.y, 37.0)
        XCTAssertEqual(rightTopZone.size.width, 1264.0)
        // Height: (1311 - 8)/2 = 651.5 -> rounded to 652
        XCTAssertEqual(rightTopZone.size.height, 652.0)
        
        // Test Right Bottom 25% zone
        let rightBottomZone = DisplayManager.shared.calculateZoneRect(
            on: display,
            relativeRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            gap: 8.0,
            padding: 12.0
        )
        
        XCTAssertEqual(rightBottomZone.origin.x, 1284.0)
        XCTAssertEqual(rightBottomZone.origin.y, 697.0) // 37 + 651.5 + 8 -> rounded
        XCTAssertEqual(rightBottomZone.size.width, 1264.0)
        XCTAssertEqual(rightBottomZone.size.height, 652.0)
    }
    
    @MainActor
    func testCoordinateConversionAccuracy() {
        let displays = DisplayManager.shared.getDisplays()
        XCTAssertFalse(displays.isEmpty, "Should detect at least one connected display")
        
        for d in displays {
            // In AX coordinates, Y=0 is the top of the primary display
            XCTAssertGreaterThanOrEqual(d.axFrame.size.width, 800)
            XCTAssertGreaterThanOrEqual(d.axFrame.size.height, 600)
            
            // Usable frame height should be less than or equal to total screen height
            XCTAssertLessThanOrEqual(d.axVisibleFrame.size.height, d.axFrame.size.height)
            XCTAssertLessThanOrEqual(d.axVisibleFrame.size.width, d.axFrame.size.width)
        }
    }
    
    @MainActor
    func testSnapshotCreationAndVerification() {
        let mockFrames: [CGWindowID: CGRect] = [
            101: CGRect(x: 0, y: 30, width: 700, height: 700),
            102: CGRect(x: 710, y: 30, width: 700, height: 700)
        ]
        
        let snapshot = RestoreSnapshot(timestamp: Date(), windowFrames: mockFrames)
        XCTAssertEqual(snapshot.windowFrames.count, 2)
        XCTAssertEqual(snapshot.windowFrames[101]?.origin.x, 0)
        XCTAssertEqual(snapshot.windowFrames[102]?.origin.x, 710)
    }
    
    @MainActor
    func testHotKeyManagerRegistration() {
        let hotKey = HotKey(id: 99, keyCode: 49, modifiers: 0x0800, name: "Test Option+Space")
        var triggered = false
        
        let registered = HotKeyManager.shared.register(hotKey: hotKey) {
            triggered = true
        }
        
        XCTAssertTrue(registered, "Carbon hotkey registration should succeed")
        HotKeyManager.shared.unregister(id: 99)
    }
}
