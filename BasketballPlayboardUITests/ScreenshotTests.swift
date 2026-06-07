import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func testTakeScreenshots() {
        sleep(2)

        // Screenshot 1: Half court (default state)
        let shot1 = XCUIScreen.main.screenshot()
        let attach1 = XCTAttachment(screenshot: shot1)
        attach1.name = "01_halfcourt"
        attach1.lifetime = .keepAlways
        add(attach1)
        saveScreenshot(shot1.pngRepresentation, name: "screenshot_1_halfcourt.png")

        // Tap "Half" button to switch to Full court
        let halfButton = app.buttons["Half"]
        if halfButton.exists {
            halfButton.tap()
            sleep(1)
        }

        // Screenshot 2: Full court
        let shot2 = XCUIScreen.main.screenshot()
        let attach2 = XCTAttachment(screenshot: shot2)
        attach2.name = "02_fullcourt"
        attach2.lifetime = .keepAlways
        add(attach2)
        saveScreenshot(shot2.pngRepresentation, name: "screenshot_2_fullcourt.png")

        // Tap "Full" to go back to Half
        let fullButton = app.buttons["Full"]
        if fullButton.exists {
            fullButton.tap()
            sleep(1)
        }

        // Tap draw mode (pencil icon)
        let pencilButton = app.buttons.matching(identifier: "pencil.tip").firstMatch
        if pencilButton.exists {
            pencilButton.tap()
            sleep(1)
        }

        // Screenshot 3: Draw mode with tools visible
        let shot3 = XCUIScreen.main.screenshot()
        let attach3 = XCTAttachment(screenshot: shot3)
        attach3.name = "03_drawtools"
        attach3.lifetime = .keepAlways
        add(attach3)
        saveScreenshot(shot3.pngRepresentation, name: "screenshot_3_drawtools.png")

        // Draw a line on the court
        let courtArea = app.otherElements.firstMatch
        let start = courtArea.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let end = courtArea.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)

        // Screenshot 4: With drawn line
        let shot4 = XCUIScreen.main.screenshot()
        let attach4 = XCTAttachment(screenshot: shot4)
        attach4.name = "04_withline"
        attach4.lifetime = .keepAlways
        add(attach4)
        saveScreenshot(shot4.pngRepresentation, name: "screenshot_4_withline.png")
    }

    private func saveScreenshot(_ data: Data, name: String) {
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp/appstore_screenshots"
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }
}
