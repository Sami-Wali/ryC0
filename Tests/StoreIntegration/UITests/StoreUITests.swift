import XCTest

final class StoreUITests: XCTestCase {
    private func launcher() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.ry0.ryC0.storetest")
        app.launch()
        for _ in 0..<3 {
            let alert = app.alerts.firstMatch
            if alert.waitForExistence(timeout: 1), alert.buttons["OK"].exists { alert.buttons["OK"].tap() }
        }
        return app
    }
    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testRyP0IsPreinstalled() {
        let app = launcher()
        XCTAssertTrue(app.buttons["ryP0"].waitForExistence(timeout: 12))
        capture(app, name: "ryP0 installed on Home")
    }

    func testDockPagingAndNotificationCenter() {
        let app = launcher()
        let pages = app.buttons["ryc0.dock.pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 8))
        XCTAssertEqual(pages.value as? String, "1 / 2")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.77, dy: 0.929))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.929))
        start.press(forDuration: 0.05, thenDragTo: end)
        let second = expectation(for: NSPredicate(format: "value == %@", "2 / 2"), evaluatedWith: pages)
        wait(for: [second], timeout: 4)
        XCTAssertTrue(app.buttons["Fixture 5"].exists)
        capture(app, name: "Liquid Glass Dock Page 2")

        let clock = app.buttons["ryc0.notifications.open"]
        XCTAssertTrue(clock.exists)
        let below = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.43))
        clock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.05, thenDragTo: below)
        XCTAssertTrue(app.staticTexts["Fixture Reminder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Scheduled for tomorrow"].exists)
        capture(app, name: "Notification Center")
        app.buttons["Clear"].tap()
        XCTAssertTrue(app.staticTexts["No Notifications"].exists)
        app.buttons["ryc0.notifications.close"].tap()
    }

    func testSwitcherScrollAndCloseFromMenu() {
        let app = launcher()
        let switcher = app.buttons["ryc0.app-switcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 8))
        switcher.tap()
        let cards = app.buttons.matching(identifier: "ryc0.switcher.card")
        XCTAssertGreaterThanOrEqual(cards.count, 3)
        capture(app, name: "Refined Switcher First Card")
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.55))
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.55))
        center.press(forDuration: 0.05, thenDragTo: right, withVelocity: .slow, thenHoldForDuration: 0.05)
        capture(app, name: "Refined Switcher Scrolled")
        let before = cards.count
        center.press(forDuration: 0.7)
        let close = app.buttons["Close Fixture 2"]
        XCTAssertTrue(close.waitForExistence(timeout: 4))
        close.tap()
        let dismissed = expectation(for: NSPredicate { _, _ in cards.count < before }, evaluatedWith: nil)
        wait(for: [dismissed], timeout: 4)
        XCTAssertTrue(app.buttons["ryc0.switcher.home"].exists)
        app.buttons["ryc0.switcher.home"].tap()
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
    }
}
