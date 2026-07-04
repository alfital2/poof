import XCTest
@testable import PoofCore

final class ConfigTests: XCTestCase {
    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "fps")
    }

    func testDefaultFPSWhenUnset() {
        UserDefaults.standard.removeObject(forKey: "fps")
        XCTAssertEqual(Config.fps, 15)
    }

    func testFPSPersistsWhenValid() {
        Config.fps = 20
        XCTAssertEqual(Config.fps, 20)
    }

    func testInvalidFPSFallsBackToDefault() {
        UserDefaults.standard.set(999, forKey: "fps")
        XCTAssertEqual(Config.fps, 15)
    }

    func testConstantsSane() {
        XCTAssertGreaterThan(Config.maxWidth, 0)
        XCTAssertGreaterThan(Config.maxDuration, 0)
        XCTAssertTrue(Config.availableFPS.contains(Config.defaultFPS))
    }
}
