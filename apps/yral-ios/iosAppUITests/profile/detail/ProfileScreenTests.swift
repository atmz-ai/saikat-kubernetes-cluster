import XCTest
import XCUIAutomation

final class ProfileScreenTests: XCTestCase {
  @MainActor
  func testProfileEditingValidationAndCancellation() {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()

    let profileTab = application.tabBars.buttons["Profile"]
    XCTAssertTrue(profileTab.waitForExistence(timeout: 30))
    profileTab.tap()

    let editButton = application.buttons["profile.edit"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 30))
    XCTAssertTrue(application.staticTexts["Followers"].exists)
    XCTAssertTrue(application.staticTexts["Following"].exists)
    let originalBio = application.staticTexts["profile.bio"].label
    editButton.tap()

    let bioEditor = application.textViews["profile.bioEditor"]
    XCTAssertTrue(bioEditor.waitForExistence(timeout: 10))
    bioEditor.tap()
    bioEditor.typeText(" Unsaved UI test draft")

    let websiteEditor = application.textFields["profile.websiteEditor"]
    websiteEditor.tap()
    let existingWebsite = websiteEditor.value as? String ?? ""
    if existingWebsite.hasPrefix("http") {
      websiteEditor.typeText(
        String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingWebsite.count))
    }
    websiteEditor.typeText("javascript:alert(1)")
    application.buttons["profile.save"].tap()
    XCTAssertTrue(application.staticTexts["profile.error"].waitForExistence(timeout: 5))
    XCTAssertTrue(application.textViews["profile.bioEditor"].exists)

    application.buttons["profile.cancel"].tap()
    XCTAssertTrue(editButton.waitForExistence(timeout: 5))
    XCTAssertEqual(application.staticTexts["profile.bio"].label, originalBio)
    XCTAssertFalse(application.textViews["profile.bioEditor"].exists)

    let screenshot = XCTAttachment(screenshot: application.screenshot())
    screenshot.name = "Profile after cancelling edits"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
