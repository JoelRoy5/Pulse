import XCTest

final class ScrollScreenshotTest: XCTestCase {
    func testCaptureStreakWidget() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-PulseSkipOnboarding", "YES",
            "-PulseMockState", "exhausted_depleted",
            "-PulseAutoDeliver", "YES"
        ]
        app.launch()
        
        // Wait for app to settle and deliver verse
        Thread.sleep(forTimeInterval: 6)
        
        // Scroll down to reveal streak widget
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        scrollView.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        
        // Take screenshot
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "streak-widget-screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Save to /tmp
        let pngData = screenshot.pngRepresentation
        try? pngData.write(to: URL(fileURLWithPath: "/tmp/p2-streak-uitest.png"))
        
        XCTAssert(true, "Screenshot captured")
    }
}
