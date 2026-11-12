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

    func testNativeSwitcherHeadersAndBrowsing() {
        let app = launcher()
        let switcher = app.buttons["ryc0.app-switcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 8))
        switcher.tap()
        let cards = app.buttons.matching(identifier: "ryc0.switcher.card")
        let focused = cards.matching(NSPredicate(format: "isSelected == true"))
        XCTAssertTrue(focused.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ryc0.switcher.error"].exists)
        XCTAssertEqual(focused.firstMatch.label, "Fixture 1")
        XCTAssertEqual(focused.firstMatch.frame.width / app.frame.width, 0.685, accuracy: 0.02)
        capture(app, name: "Native Switcher From Home")
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.55))
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.55))
        center.press(forDuration: 0.05, thenDragTo: right, withVelocity: .slow, thenHoldForDuration: 0.05)
        let changed = expectation(for: NSPredicate { _, _ in focused.count == 1 && focused.firstMatch.label != "Fixture 1" }, evaluatedWith: nil)
        wait(for: [changed], timeout: 4)
        capture(app, name: "Native Switcher Scrolled")
        app.buttons["ryc0.switcher.home"].tap()
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
    }

    func testSwitcherSelectingCardDoesNotCrash() {
        let app = launcher()
        let switcher = app.buttons["ryc0.app-switcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 8))
        switcher.tap()
        let focused = app.buttons.matching(identifier: "ryc0.switcher.card").matching(NSPredicate(format: "isSelected == true")).firstMatch
        XCTAssertTrue(focused.waitForExistence(timeout: 5))
        focused.tap()
        // The simulator fixture is not a runnable device guest; the app must
        // return Home and report its launch result without losing the process.
        XCTAssertTrue(switcher.waitForExistence(timeout: 15))
        XCTAssertEqual(app.state, .runningForeground)
        for alert in app.alerts.allElementsBoundByIndex {
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap() }
        }
        switcher.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "ryc0.switcher.card").firstMatch.waitForExistence(timeout: 5))
        app.buttons["ryc0.switcher.home"].tap()
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
    }

    private func cardCount(_ card: XCUIElement) -> Int {
        guard let value = card.value as? String,
              let count = value.split(separator: "/").last else { return -1 }
        return Int(count.trimmingCharacters(in: .whitespaces)) ?? -1
    }

    func testSwitcherSwipeCloseAndContinueBrowsing() {
        let app = launcher()
        let switcher = app.buttons["ryc0.app-switcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 8))
        switcher.tap()
        let cards = app.buttons.matching(identifier: "ryc0.switcher.card")
        let focused = cards.matching(NSPredicate(format: "isSelected == true"))
        XCTAssertTrue(focused.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(focused.count, 1)
        let before = cardCount(focused.firstMatch)
        let dismissedName = focused.firstMatch.label
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        center.press(forDuration: 0.05, thenDragTo: top, withVelocity: .fast, thenHoldForDuration: 0)
        let removed = expectation(for: NSPredicate { _, _ in
            focused.count == 1 && focused.firstMatch.label != dismissedName && self.cardCount(focused.firstMatch) == before - 1
        }, evaluatedWith: nil)
        wait(for: [removed], timeout: 4)
        capture(app, name: "Switcher Settled After Swipe Close")
        let nextName = focused.firstMatch.label
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.55))
        center.press(forDuration: 0.05, thenDragTo: right, withVelocity: .slow, thenHoldForDuration: 0)
        let browsed = expectation(for: NSPredicate { _, _ in
            focused.count == 1 && focused.firstMatch.label != nextName
        }, evaluatedWith: nil)
        wait(for: [browsed], timeout: 4)
        XCTAssertEqual(cardCount(focused.firstMatch), before - 1)
        let olderName = focused.firstMatch.label
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.55))
        center.press(forDuration: 0.05, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0)
        let returned = expectation(for: NSPredicate { _, _ in
            focused.count == 1 && focused.firstMatch.label != olderName
        }, evaluatedWith: nil)
        wait(for: [returned], timeout: 4)
        XCTAssertEqual(cardCount(focused.firstMatch), before - 1)
        app.buttons["ryc0.switcher.home"].tap()
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
    }
}
