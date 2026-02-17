import XCTest

final class ProgramsMenuNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMenuReturnsToProgramsChannelListFromDetail() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uitest-sample-data")
        app.launchArguments.append("-uitest-open-programs-tab")
        app.launchArguments.append("-uitest-auto-open-program-detail")
        app.launch()

        let channelList = app.tables["programs.channelList"]
        let detailList = app.tables["programs.detailList"]
        XCTAssertTrue(detailList.waitForExistence(timeout: 10), "Programs detail should be visible")

        XCUIRemote.shared.press(.menu)

        let detailDismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: detailList)
        wait(for: [detailDismissed], timeout: 10)

        XCTAssertTrue(channelList.waitForExistence(timeout: 10), "Menu should return to channel list")
        XCTAssertEqual(app.state, .runningForeground, "App should remain foreground after Menu back")
    }
}
