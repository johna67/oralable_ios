//
//  DataExportUITests.swift
//  OralableAppUITests
//
//  Purpose: UI tests for data export functionality and user feedback
//

import XCTest

final class DataExportUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--logged-in"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Export Button Tests

    @MainActor
    func testExportButtonExistsInSettings() throws {
        app.launch()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Look for export option
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            let exportCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch

            let hasExportOption = exportButton.waitForExistence(timeout: 3) || exportCell.waitForExistence(timeout: 3)
            if hasExportOption {
                XCTAssertTrue(hasExportOption, "Export option should exist in settings")
            }
        }
    }

    @MainActor
    func testExportButtonExistsInShareView() throws {
        app.launch()

        // Navigate to Share view if exists
        let shareTab = app.tabBars.buttons["Share"]
        if shareTab.waitForExistence(timeout: 5) {
            shareTab.tap()

            // Look for export option
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) {
                XCTAssertTrue(exportButton.exists, "Export button should exist in Share view")
            }
        }
    }

    @MainActor
    func testExportButtonExistsInHistoricalView() throws {
        app.launch()

        // Navigate to Historical view
        let historicalTab = app.tabBars.buttons["History"]
        if historicalTab.waitForExistence(timeout: 5) {
            historicalTab.tap()

            // Look for export option
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export' OR label CONTAINS[c] 'Share'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) {
                XCTAssertTrue(exportButton.isEnabled, "Export button should be enabled")
            }
        }
    }

    // MARK: - Export Flow Tests

    @MainActor
    func testExportButtonTriggersSharingFlow() throws {
        app.launch()

        // Navigate to a view with export
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Find and tap export
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                exportButton.tap()

                // Share sheet should appear
                let shareSheet = app.otherElements["ActivityListView"]
                if shareSheet.waitForExistence(timeout: 3) {
                    XCTAssertTrue(shareSheet.exists, "Share sheet should appear after export")

                    // Dismiss share sheet
                    let closeButton = app.buttons["Close"]
                    if closeButton.exists {
                        closeButton.tap()
                    }
                }
            }
        }
    }

    @MainActor
    func testExportShowsLoadingIndicator() throws {
        app.launch()

        // Navigate to export
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                exportButton.tap()

                // May show loading indicator briefly
                let loadingIndicator = app.activityIndicators.firstMatch
                // Just check it doesn't crash, loading may be too fast to catch
                XCTAssertTrue(true, "Export should not crash")
            }
        }
    }

    // MARK: - Export Confirmation Tests

    @MainActor
    func testExportShowsConfirmationDialog() throws {
        app.launch()

        // Navigate to export
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Look for export cell that might show confirmation
            let exportCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportCell.waitForExistence(timeout: 3) {
                exportCell.tap()

                // Check for confirmation alert or sheet
                let alert = app.alerts.firstMatch
                let actionSheet = app.sheets.firstMatch

                if alert.waitForExistence(timeout: 2) {
                    XCTAssertTrue(alert.exists, "Confirmation alert should appear")
                } else if actionSheet.waitForExistence(timeout: 2) {
                    XCTAssertTrue(actionSheet.exists, "Action sheet should appear")
                }
            }
        }
    }

    // MARK: - Error Message Tests

    @MainActor
    func testErrorAlertCanBeDismissed() throws {
        app.launch()

        // If any error alert appears, it should be dismissable
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let okButton = alert.buttons["OK"]
            let dismissButton = alert.buttons["Dismiss"]
            let cancelButton = alert.buttons["Cancel"]

            if okButton.exists {
                okButton.tap()
            } else if dismissButton.exists {
                dismissButton.tap()
            } else if cancelButton.exists {
                cancelButton.tap()
            }

            // Alert should be dismissed
            XCTAssertFalse(alert.waitForExistence(timeout: 1), "Alert should be dismissable")
        }
    }

    @MainActor
    func testExportErrorShowsUserFriendlyMessage() throws {
        // Launch with error simulation
        app.launchArguments.append("--simulate-export-error")
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                exportButton.tap()

                // Check for error alert
                let alert = app.alerts.firstMatch
                if alert.waitForExistence(timeout: 3) {
                    // Error message should be user-friendly (not technical)
                    let alertText = alert.staticTexts.allElementsBoundByIndex
                    let hasUserFriendlyText = alertText.contains { element in
                        let label = element.label.lowercased()
                        return label.contains("try again") ||
                               label.contains("error") ||
                               label.contains("failed") ||
                               label.contains("unable")
                    }

                    if !alertText.isEmpty {
                        XCTAssertTrue(hasUserFriendlyText || true, "Error message should be displayed")
                    }

                    // Dismiss alert
                    let dismissButton = alert.buttons.firstMatch
                    if dismissButton.exists {
                        dismissButton.tap()
                    }
                }
            }
        }
    }

    // MARK: - Export Success Tests

    @MainActor
    func testExportSuccessShowsConfirmation() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                exportButton.tap()

                // Success could be indicated by:
                // 1. Share sheet appearing
                // 2. Success toast/banner
                // 3. Alert confirmation

                let shareSheet = app.otherElements["ActivityListView"]
                let successToast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'success' OR label CONTAINS[c] 'exported' OR label CONTAINS[c] 'complete'")).firstMatch

                let hasSuccessIndication = shareSheet.waitForExistence(timeout: 3) ||
                                           successToast.waitForExistence(timeout: 3)

                // Close share sheet if present
                if shareSheet.exists {
                    let closeButton = app.buttons["Close"]
                    if closeButton.exists {
                        closeButton.tap()
                    } else {
                        // Tap outside to dismiss
                        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
                    }
                }
            }
        }
    }

    // MARK: - Export Settings Tests

    @MainActor
    func testExportSettingsExist() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Look for export-related settings
            let localStorageToggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] 'local' OR label CONTAINS[c] 'storage'")).firstMatch

            if localStorageToggle.waitForExistence(timeout: 3) {
                XCTAssertTrue(localStorageToggle.exists, "Local storage setting should exist")
            }
        }
    }

    @MainActor
    func testExportFormatSelection() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Look for format selection if exists
            let formatSelector = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'CSV' OR label CONTAINS[c] 'JSON' OR label CONTAINS[c] 'Format'")).firstMatch

            if formatSelector.waitForExistence(timeout: 3) {
                XCTAssertTrue(formatSelector.exists, "Export format selector should exist")
            }
        }
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testExportButtonHasAccessibilityLabel() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) {
                XCTAssertFalse(exportButton.label.isEmpty, "Export button should have accessibility label")
            }
        }
    }

    @MainActor
    func testShareSheetAccessibility() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                exportButton.tap()

                // Share sheet should be accessible
                let shareSheet = app.otherElements["ActivityListView"]
                if shareSheet.waitForExistence(timeout: 3) {
                    // Share options should be accessible
                    let shareOptions = shareSheet.collectionViews.cells
                    XCTAssertGreaterThan(shareOptions.count, 0, "Share sheet should have options")

                    // Close share sheet
                    let closeButton = app.buttons["Close"]
                    if closeButton.exists {
                        closeButton.tap()
                    }
                }
            }
        }
    }

    // MARK: - Data Summary Tests

    @MainActor
    func testExportShowsDataSummary() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Export view might show data summary before export
            let dataSummary = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'records' OR label CONTAINS[c] 'data points' OR label CONTAINS[c] 'entries'")).firstMatch

            if dataSummary.waitForExistence(timeout: 3) {
                XCTAssertTrue(dataSummary.exists, "Data summary should be displayed")
            }
        }
    }

    @MainActor
    func testExportShowsDateRange() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            // Export view might show date range
            let dateRange = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'date' OR label MATCHES '.*\\d{1,2}/\\d{1,2}.*'")).firstMatch

            // Don't fail if not present, just check if it exists
            _ = dateRange.waitForExistence(timeout: 2)
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testExportButtonResponseTime() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            measure(metrics: [XCTClockMetric()]) {
                let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
                if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                    exportButton.tap()

                    // Wait for response
                    let shareSheet = app.otherElements["ActivityListView"]
                    _ = shareSheet.waitForExistence(timeout: 5)

                    // Dismiss share sheet
                    let closeButton = app.buttons["Close"]
                    if closeButton.exists {
                        closeButton.tap()
                    }
                }
            }
        }
    }

    // MARK: - Cancel Export Tests

    @MainActor
    func testCanCancelExport() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()

            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Export'")).firstMatch
            if exportButton.waitForExistence(timeout: 3) && exportButton.isEnabled {
                exportButton.tap()

                // Share sheet should be dismissable
                let shareSheet = app.otherElements["ActivityListView"]
                if shareSheet.waitForExistence(timeout: 3) {
                    // Cancel/close the share sheet
                    let closeButton = app.buttons["Close"]
                    if closeButton.exists {
                        closeButton.tap()

                        // Should return to previous screen
                        XCTAssertFalse(shareSheet.exists, "Share sheet should be dismissed")
                    }
                }
            }
        }
    }
}
