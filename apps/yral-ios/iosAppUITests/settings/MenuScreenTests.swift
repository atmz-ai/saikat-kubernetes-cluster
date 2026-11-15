import XCTest
import XCUIAutomation

final class MenuScreenTests: XCTestCase {
  @MainActor
  func testMenuOpensSettings() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()

    XCTAssertTrue(application.staticTexts["Settings"].waitForExistence(timeout: 30))
    XCTAssertTrue(application.staticTexts["settings.version"].exists)
    XCTAssertTrue(application.buttons["settings.authentication"].exists)
    XCTAssertFalse(application.buttons["Switch account"].exists)
    XCTAssertFalse(application.buttons["Delete account"].exists)
    XCTAssertFalse(application.tabBars.buttons["Profile"].exists)
    XCTAssertFalse(application.switches["Notifications"].exists)

    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Settings"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
