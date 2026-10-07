import XCTest
import XCUIAutomation

final class HomeFeedScreenTests: XCTestCase {
  @MainActor
  func testHomeDiscoverySearchFieldAndClear() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()

    let homeTab = application.tabBars.buttons["Home"]
    XCTAssertTrue(homeTab.waitForExistence(timeout: 30))
    homeTab.tap()

    XCTAssertTrue(application.navigationBars["Discover"].waitForExistence(timeout: 10))
    let searchField = application.searchFields["Search AI influencers"]
    XCTAssertTrue(searchField.waitForExistence(timeout: 10))
    searchField.tap()
    searchField.typeText("aura")
    XCTAssertEqual(searchField.value as? String, "aura")

    let clearButton = searchField.buttons["Clear text"]
    XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
    clearButton.tap()
    XCTAssertNotEqual(searchField.value as? String, "aura")

    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Home discovery after clearing search"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
