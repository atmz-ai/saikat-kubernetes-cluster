import XCTest
import XCUIAutomation

final class MenuScreenTests: XCTestCase {
  @MainActor
  func testMenuOpensSettings() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()

    let menuButton = application.tabBars.buttons["Menu"]
    XCTAssertTrue(menuButton.waitForExistence(timeout: 30))
    menuButton.tap()

    XCTAssertTrue(application.staticTexts["Settings"].waitForExistence(timeout: 10))
    XCTAssertTrue(application.staticTexts["Notifications"].exists)

    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Settings"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
