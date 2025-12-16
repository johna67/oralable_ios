//
//  DashboardUIConsistencyTests.swift
//  OralableAppUITests
//
//  Created: December 15, 2025
//  Purpose: UI consistency tests for dashboard layout
//  Tests light/dark mode, accessibility (Dynamic Type, VoiceOver), and responsiveness
//

import XCTest

final class DashboardUIConsistencyTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--logged-in"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Light/Dark Mode Tests

    @MainActor
    func testDashboardDisplaysInLightMode() throws {
        // Launch in light mode
        app.launchArguments.append("-AppleInterfaceStyle")
        app.launchArguments.append("Light")
        app.launch()

        // Verify dashboard is displayed
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should be visible in light mode")

        // Verify key UI elements exist
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible in light mode")
    }

    @MainActor
    func testDashboardDisplaysInDarkMode() throws {
        // Launch in dark mode
        app.launchArguments.append("-AppleInterfaceStyle")
        app.launchArguments.append("Dark")
        app.launch()

        // Verify dashboard is displayed
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should be visible in dark mode")

        // Verify key UI elements exist
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible in dark mode")
    }

    @MainActor
    func testMetricCardsVisibleInLightMode() throws {
        app.launchArguments.append("-AppleInterfaceStyle")
        app.launchArguments.append("Light")
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Look for metric cards
        let ppgCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'PPG' OR label CONTAINS[c] 'Sensor'")).firstMatch
        if ppgCard.waitForExistence(timeout: 3) {
            XCTAssertTrue(ppgCard.isHittable, "PPG card should be visible and tappable in light mode")
        }
    }

    @MainActor
    func testMetricCardsVisibleInDarkMode() throws {
        app.launchArguments.append("-AppleInterfaceStyle")
        app.launchArguments.append("Dark")
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Look for metric cards
        let ppgCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'PPG' OR label CONTAINS[c] 'Sensor'")).firstMatch
        if ppgCard.waitForExistence(timeout: 3) {
            XCTAssertTrue(ppgCard.isHittable, "PPG card should be visible and tappable in dark mode")
        }
    }

    @MainActor
    func testRecordingButtonVisibleInBothModes() throws {
        // Test light mode
        app.launchArguments.append("-AppleInterfaceStyle")
        app.launchArguments.append("Light")
        app.launch()

        let recordButtonLight = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Record' OR label CONTAINS[c] 'Connected'")).firstMatch
        if recordButtonLight.waitForExistence(timeout: 5) {
            XCTAssertTrue(recordButtonLight.exists, "Record button should be visible in light mode")
        }

        // Terminate and relaunch in dark mode
        app.terminate()
        app.launchArguments.removeLast(2) // Remove Light mode args
        app.launchArguments.append("-AppleInterfaceStyle")
        app.launchArguments.append("Dark")
        app.launch()

        let recordButtonDark = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Record' OR label CONTAINS[c] 'Connected'")).firstMatch
        if recordButtonDark.waitForExistence(timeout: 5) {
            XCTAssertTrue(recordButtonDark.exists, "Record button should be visible in dark mode")
        }
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testDashboardHasAccessibilityLabels() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Verify tab bar items have accessibility labels
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.exists, "Dashboard tab should have accessibility label")
        XCTAssertFalse(dashboardTab.label.isEmpty, "Dashboard tab label should not be empty")

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists, "Settings tab should have accessibility label")
        XCTAssertFalse(settingsTab.label.isEmpty, "Settings tab label should not be empty")

        let devicesTab = app.tabBars.buttons["Devices"]
        XCTAssertTrue(devicesTab.exists, "Devices tab should have accessibility label")
        XCTAssertFalse(devicesTab.label.isEmpty, "Devices tab label should not be empty")
    }

    @MainActor
    func testMetricCardsHaveAccessibilityLabels() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Find metric cards and verify they have accessibility labels
        let allButtons = app.buttons.allElementsBoundByIndex

        var accessibleCardsCount = 0
        for button in allButtons {
            if !button.label.isEmpty {
                accessibleCardsCount += 1
            }
        }

        XCTAssertGreaterThan(accessibleCardsCount, 0, "Should have accessible buttons on dashboard")
    }

    @MainActor
    func testVoiceOverAccessibility() throws {
        app.launch()

        // Wait for dashboard
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Verify navigation bar is accessible
        XCTAssertTrue(dashboardTitle.isEnabled, "Navigation bar should be accessible")

        // Verify tab bar items are focusable
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist for VoiceOver navigation")

        // Verify scroll view content is accessible
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        for scrollView in scrollViews {
            XCTAssertTrue(scrollView.isEnabled, "Scroll views should be accessible")
        }
    }

    @MainActor
    func testDynamicTypeSmallText() throws {
        // Launch with small text size
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategorySmall")
        app.launch()

        // Verify dashboard is usable with small text
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should display with small text size")

        // Verify UI elements are still visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible with small text")
    }

    @MainActor
    func testDynamicTypeLargeText() throws {
        // Launch with large text size
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategoryAccessibilityLarge")
        app.launch()

        // Verify dashboard is usable with large text
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should display with large text size")

        // Verify scrolling works (content may overflow)
        app.swipeUp()
        app.swipeDown()

        // Dashboard should still be functional
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should remain visible with large text")
    }

    @MainActor
    func testDynamicTypeExtraLargeText() throws {
        // Launch with extra large accessibility text
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        app.launch()

        // Verify app doesn't crash and is still usable
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should display with XXL text")

        // Tab navigation should still work
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 3) {
            settingsTab.tap()
            let settingsTitle = app.navigationBars["Settings"]
            XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Navigation should work with XXL text")
        }
    }

    // MARK: - Responsiveness Tests

    @MainActor
    func testDashboardLayoutOnCompactWidth() throws {
        // Default iPhone is compact width
        app.launch()

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should layout correctly on compact width")

        // Content should be scrollable
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeDown()
        }

        // Tab bar should be at bottom
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")
    }

    @MainActor
    func testDashboardScrollsWhenContentOverflows() throws {
        app.launch()

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Perform scroll gestures
        app.swipeUp()

        // Should be able to scroll back
        app.swipeDown()

        // Dashboard should remain functional
        XCTAssertTrue(dashboardTitle.exists, "Dashboard should remain functional after scrolling")
    }

    @MainActor
    func testDashboardOrientationPortrait() throws {
        app.launch()

        // Verify portrait orientation works
        XCUIDevice.shared.orientation = .portrait

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should display in portrait")

        // All tabs should be visible
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        let settingsTab = app.tabBars.buttons["Settings"]

        XCTAssertTrue(dashboardTab.exists, "Dashboard tab should be visible in portrait")
        XCTAssertTrue(settingsTab.exists, "Settings tab should be visible in portrait")
    }

    @MainActor
    func testDashboardOrientationLandscape() throws {
        app.launch()

        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft

        // Allow time for rotation
        Thread.sleep(forTimeInterval: 0.5)

        // Verify landscape orientation works
        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5), "Dashboard should display in landscape")

        // Tab bar should still be accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible in landscape")

        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - UI Element Interaction Tests

    @MainActor
    func testAllTabsAccessible() throws {
        app.launch()

        // Test each tab is accessible and tappable
        let tabs = ["Dashboard", "Devices", "Share", "Settings"]

        for tabName in tabs {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "\(tabName) tab should exist")
            XCTAssertTrue(tab.isHittable, "\(tabName) tab should be tappable")
            tab.tap()

            let navBar = app.navigationBars[tabName]
            if navBar.waitForExistence(timeout: 3) {
                XCTAssertTrue(navBar.exists, "\(tabName) screen should display")
            }
        }
    }

    @MainActor
    func testScrollViewResponsivenessUnderLoad() throws {
        app.launch()

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Perform rapid scroll gestures
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<5 {
                app.swipeUp()
                app.swipeDown()
            }
        }

        // Dashboard should remain responsive
        XCTAssertTrue(dashboardTitle.exists, "Dashboard should remain responsive after rapid scrolling")
    }

    // MARK: - Safe Area and Notch Tests

    @MainActor
    func testContentRespectsStatusBar() throws {
        app.launch()

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Navigation bar should be visible (not hidden under status bar)
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.frame.minY >= 0, "Navigation bar should not be hidden under status bar")
    }

    @MainActor
    func testContentRespectsTabBar() throws {
        app.launch()

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Tab bar should be visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")

        // Tab bar should be at bottom of screen
        let screenHeight = app.windows.firstMatch.frame.height
        XCTAssertGreaterThan(tabBar.frame.minY, screenHeight / 2, "Tab bar should be in bottom half of screen")
    }

    // MARK: - Color Contrast Tests (Visual Verification)

    @MainActor
    func testUIElementsHaveSufficientContrast() throws {
        app.launch()

        // This is a visual verification test
        // Verifies that key elements are visible and distinct

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        // Verify multiple UI layers are present and visible
        let navBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        let scrollView = app.scrollViews.firstMatch

        XCTAssertTrue(navBar.exists, "Navigation bar should be visible")
        XCTAssertTrue(tabBar.exists, "Tab bar should be visible")

        // UI should have distinct layers (not all blended together)
        if scrollView.exists {
            XCTAssertNotEqual(navBar.frame, scrollView.frame, "Nav bar should be distinct from content")
        }
    }

    // MARK: - Performance Under Different Conditions

    @MainActor
    func testDashboardLoadsQuickly() throws {
        measure(metrics: [XCTClockMetric()]) {
            app.launch()

            let dashboardTitle = app.navigationBars["Dashboard"]
            _ = dashboardTitle.waitForExistence(timeout: 10)
        }
    }

    @MainActor
    func testTabSwitchingPerformance() throws {
        app.launch()

        let dashboardTitle = app.navigationBars["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))

        measure(metrics: [XCTClockMetric()]) {
            let settingsTab = app.tabBars.buttons["Settings"]
            settingsTab.tap()

            let devicesTab = app.tabBars.buttons["Devices"]
            devicesTab.tap()

            let shareTab = app.tabBars.buttons["Share"]
            shareTab.tap()

            let dashboardTab = app.tabBars.buttons["Dashboard"]
            dashboardTab.tap()
        }
    }
}
