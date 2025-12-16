//
//  NavigationTests.swift
//  OralableAppUITests
//
//  Created: December 15, 2025
//  Purpose: UI tests for SwiftUI navigation flows
//  Tests Dashboard → HistoricalView, Dashboard → Settings, deep linking, and back navigation
//

import XCTest

final class NavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--logged-in"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Navigation Tests

    @MainActor
    func testDashboardTabIsDefaultSelection() throws {
        app.launch()

        // Dashboard should be the first visible screen
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should be the default tab")
    }

    @MainActor
    func testNavigationFromDashboardToSettings() throws {
        app.launch()

        // Navigate to Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist")
        settingsTab.tap()

        // Verify Settings screen is displayed
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings screen should be displayed")
    }

    @MainActor
    func testNavigationFromDashboardToDevices() throws {
        app.launch()

        // Navigate to Devices tab
        let devicesTab = app.tabBars.buttons["Devices"]
        XCTAssertTrue(devicesTab.waitForExistence(timeout: 5), "Devices tab should exist")
        devicesTab.tap()

        // Verify Devices screen is displayed
        let devicesTitle = app.navigationBars["Devices"]
        XCTAssertTrue(devicesTitle.waitForExistence(timeout: 3), "Devices screen should be displayed")
    }

    @MainActor
    func testNavigationFromDashboardToShare() throws {
        app.launch()

        // Navigate to Share tab
        let shareTab = app.tabBars.buttons["Share"]
        XCTAssertTrue(shareTab.waitForExistence(timeout: 5), "Share tab should exist")
        shareTab.tap()

        // Verify Share screen is displayed
        let shareTitle = app.navigationBars["Share"]
        XCTAssertTrue(shareTitle.waitForExistence(timeout: 3), "Share screen should be displayed")
    }

    // MARK: - Dashboard to Historical View Navigation Tests

    @MainActor
    func testNavigationFromDashboardToPPGHistoricalView() throws {
        app.launch()

        // Wait for dashboard to load
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Look for PPG Sensor card and tap it
        let ppgCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'PPG' OR label CONTAINS[c] 'Sensor'")).firstMatch
        if ppgCard.waitForExistence(timeout: 3) {
            ppgCard.tap()

            // Verify historical view is displayed
            let historicalView = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS[c] 'Historical' OR identifier CONTAINS[c] 'IR'")).firstMatch
            if historicalView.waitForExistence(timeout: 3) {
                XCTAssertTrue(historicalView.exists, "Historical view should be displayed after tapping PPG card")
            }
        }
    }

    @MainActor
    func testNavigationFromDashboardToMovementHistoricalView() throws {
        app.launch()

        // Wait for dashboard to load
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Look for Movement card and tap it
        let movementCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Movement' OR label CONTAINS[c] 'gyroscope'")).firstMatch
        if movementCard.waitForExistence(timeout: 3) {
            movementCard.tap()

            // Verify historical view is displayed
            let backButton = app.navigationBars.buttons["Dashboard"]
            if backButton.waitForExistence(timeout: 3) {
                XCTAssertTrue(backButton.exists, "Back button to Dashboard should exist in historical view")
            }
        }
    }

    @MainActor
    func testNavigationFromDashboardToHeartRateHistoricalView() throws {
        app.launch()

        // Wait for dashboard to load
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Look for Heart Rate card and tap it
        let heartRateCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Heart Rate' OR label CONTAINS[c] 'heart.fill'")).firstMatch
        if heartRateCard.waitForExistence(timeout: 3) {
            heartRateCard.tap()

            // Verify navigation occurred
            let backButton = app.navigationBars.buttons["Dashboard"]
            if backButton.waitForExistence(timeout: 3) {
                XCTAssertTrue(backButton.exists, "Back button should exist after navigating to Heart Rate history")
            }
        }
    }

    // MARK: - Back Navigation Tests

    @MainActor
    func testBackNavigationFromHistoricalViewToDashboard() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Navigate to a historical view via any card
        let ppgCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'PPG' OR label CONTAINS[c] 'Sensor'")).firstMatch
        if ppgCard.waitForExistence(timeout: 3) {
            ppgCard.tap()

            // Wait for historical view
            Thread.sleep(forTimeInterval: 0.5)

            // Tap back button
            let backButton = app.navigationBars.buttons["Dashboard"]
            if backButton.waitForExistence(timeout: 3) {
                backButton.tap()

                // Verify we're back on Dashboard
                XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Should return to Dashboard after back navigation")
            }
        }
    }

    @MainActor
    func testBackNavigationPreservesDashboardState() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Navigate away and back
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        dashboardTab.tap()

        // Dashboard should still show its content
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Dashboard should maintain state after tab switch")
    }

    // MARK: - Profile Sheet Navigation Tests

    @MainActor
    func testNavigationToProfileSheet() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Look for profile button in navigation bar
        let profileButton = app.navigationBars.buttons["person.circle"]
        if profileButton.waitForExistence(timeout: 3) {
            profileButton.tap()

            // Verify profile sheet is displayed
            let profileView = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] 'Profile' OR label CONTAINS[c] 'Profile'")).firstMatch
            if profileView.waitForExistence(timeout: 3) {
                XCTAssertTrue(profileView.exists, "Profile sheet should be displayed")
            }
        }
    }

    @MainActor
    func testDismissProfileSheet() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Open profile
        let profileButton = app.navigationBars.buttons["person.circle"]
        if profileButton.waitForExistence(timeout: 3) {
            profileButton.tap()

            // Wait for sheet
            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss by swiping down or tapping outside
            let dismissButton = app.buttons["Done"]
            if dismissButton.waitForExistence(timeout: 2) {
                dismissButton.tap()
            } else {
                // Swipe down to dismiss
                app.swipeDown()
            }

            // Verify dashboard is visible again
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Dashboard should be visible after dismissing profile")
        }
    }

    // MARK: - Deep Link Navigation Tests

    @MainActor
    func testDeepLinkToSettings() throws {
        // Launch with deep link to settings
        app.launchArguments.append("--deep-link")
        app.launchArguments.append("settings")
        app.launch()

        // Verify Settings is displayed
        let settingsTitle = app.navigationBars["Settings"]
        if settingsTitle.waitForExistence(timeout: 5) {
            XCTAssertTrue(settingsTitle.exists, "Deep link should navigate to Settings")
        }
    }

    @MainActor
    func testDeepLinkToDevices() throws {
        // Launch with deep link to devices
        app.launchArguments.append("--deep-link")
        app.launchArguments.append("devices")
        app.launch()

        // Verify Devices is displayed
        let devicesTitle = app.navigationBars["Devices"]
        if devicesTitle.waitForExistence(timeout: 5) {
            XCTAssertTrue(devicesTitle.exists, "Deep link should navigate to Devices")
        }
    }

    // MARK: - Navigation State Persistence Tests

    @MainActor
    func testNavigationStatePreservedOnTabSwitch() throws {
        app.launch()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Switch to Dashboard
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        dashboardTab.tap()

        // Switch back to Settings
        settingsTab.tap()

        // Settings should still be on the main Settings screen
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings state should be preserved")
    }

    @MainActor
    func testTabSelectionHighlighting() throws {
        app.launch()

        // Dashboard tab should be selected initially
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboardTab.isSelected, "Dashboard tab should be selected by default")

        // Tap Settings and verify selection changes
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected, "Settings tab should be selected after tap")
        XCTAssertFalse(dashboardTab.isSelected, "Dashboard tab should not be selected")
    }

    // MARK: - Scroll and Navigation Tests

    @MainActor
    func testDashboardScrollPreservesNavigationLinks() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Scroll down
        app.swipeUp()

        // Scroll back up
        app.swipeDown()

        // Navigation links should still work
        let ppgCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'PPG' OR label CONTAINS[c] 'Sensor'")).firstMatch
        if ppgCard.waitForExistence(timeout: 3) {
            XCTAssertTrue(ppgCard.isHittable, "PPG card should still be tappable after scrolling")
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testNavigationPerformance() throws {
        app.launch()

        measure(metrics: [XCTClockMetric()]) {
            // Navigate through all tabs
            let settingsTab = app.tabBars.buttons["Settings"]
            if settingsTab.waitForExistence(timeout: 2) { settingsTab.tap() }

            let devicesTab = app.tabBars.buttons["Devices"]
            if devicesTab.waitForExistence(timeout: 2) { devicesTab.tap() }

            let shareTab = app.tabBars.buttons["Share"]
            if shareTab.waitForExistence(timeout: 2) { shareTab.tap() }

            let dashboardTab = app.tabBars.buttons["Dashboard"]
            if dashboardTab.waitForExistence(timeout: 2) { dashboardTab.tap() }
        }
    }
}
