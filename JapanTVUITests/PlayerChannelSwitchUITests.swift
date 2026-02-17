import XCTest

@MainActor
final class PlayerChannelSwitchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLeftRightSwitchesChannelsAndMenuReturnsToChannelGrid() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uitest-sample-data")
        app.launch()

        let channelGrid = app.scrollViews["channels.grid"]
        XCTAssertTrue(channelGrid.waitForExistence(timeout: 10), "Channels grid should be visible")

        let firstChannel = app.buttons["channels.channelButton.101"]
        XCTAssertTrue(firstChannel.waitForExistence(timeout: 10), "Sample channel should be visible")
        let firstChannelFocused = expectation(
            for: NSPredicate(format: "hasFocus == true"),
            evaluatedWith: firstChannel
        )
        wait(for: [firstChannelFocused], timeout: 5)
        XCUIRemote.shared.press(.select)

        let streamView101 = app.otherElements["player.streamView.service.101"]
        XCTAssertTrue(streamView101.waitForExistence(timeout: 10), "Player should open on the selected service")

        XCUIRemote.shared.press(.right)
        let streamView102 = app.otherElements["player.streamView.service.102"]
        XCTAssertTrue(streamView102.waitForExistence(timeout: 5), "Right should switch to the next service")

        XCUIRemote.shared.press(.left)
        XCTAssertTrue(streamView101.waitForExistence(timeout: 5), "Left should switch back to the previous service")

        XCUIRemote.shared.press(.menu)

        XCTAssertTrue(channelGrid.waitForExistence(timeout: 10), "Menu should dismiss player and return to channels grid")
        XCTAssertEqual(app.state, .runningForeground, "App should remain foreground after Menu back")
    }
}
