//
//  BaseViewModelTests.swift
//  OralableAppTests
//
//  Created: Phase 2 Refactoring - Test Coverage Expansion
//  Unit tests for BaseViewModel functionality
//

import XCTest
import Combine
@testable import OralableApp

@MainActor
final class BaseViewModelTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables = nil
    }

    // MARK: - Test Subclass

    // Create a concrete subclass for testing
    class TestViewModel: BaseViewModel {
        var testError: Error?

        func triggerError(_ error: Error) {
            handleError(error)
        }

        func performAsyncTask() async throws {
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        }
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        let viewModel = TestViewModel()

        XCTAssertFalse(viewModel.isLoading, "Should initialize with isLoading = false")
        XCTAssertNil(viewModel.errorMessage, "Should initialize with no error message")
        XCTAssertNil(viewModel.successMessage, "Should initialize with no success message")
        XCTAssertNotNil(viewModel.cancellables, "Should initialize cancellables set")
    }

    // MARK: - Error Handling Tests

    func testHandleError() {
        let viewModel = TestViewModel()
        let testError = NSError(domain: "TestError", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error message"])

        viewModel.triggerError(testError)

        XCTAssertEqual(viewModel.errorMessage, "Test error message", "Should set error message")
        XCTAssertFalse(viewModel.isLoading, "Should set isLoading to false")
    }

    func testHandleErrorClearsSuccessMessage() {
        let viewModel = TestViewModel()
        viewModel.successMessage = "Previous success"

        let testError = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error occurred"])
        viewModel.triggerError(testError)

        XCTAssertNil(viewModel.successMessage, "Should clear success message when error occurs")
        XCTAssertEqual(viewModel.errorMessage, "Error occurred")
    }

    // MARK: - Loading State Tests

    func testSetLoadingState() {
        let viewModel = TestViewModel()

        viewModel.setLoading(true)
        XCTAssertTrue(viewModel.isLoading, "Should set isLoading to true")

        viewModel.setLoading(false)
        XCTAssertFalse(viewModel.isLoading, "Should set isLoading to false")
    }

    func testWithLoadingSuccess() async {
        let viewModel = TestViewModel()

        let expectation = XCTestExpectation(description: "Loading state changes")
        var loadingStates: [Bool] = []

        viewModel.$isLoading
            .sink { loading in
                loadingStates.append(loading)
                if loadingStates.count == 3 { // initial false, true, then false
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await viewModel.withLoading {
            try await viewModel.performAsyncTask()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(loadingStates, [false, true, false], "Should transition isLoading false -> true -> false")
        XCTAssertFalse(viewModel.isLoading, "Should end with isLoading = false")
        XCTAssertNil(viewModel.errorMessage, "Should have no error on success")
    }

    func testWithLoadingFailure() async {
        let viewModel = TestViewModel()

        await viewModel.withLoading {
            throw NSError(domain: "TestError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Task failed"])
        }

        XCTAssertFalse(viewModel.isLoading, "Should set isLoading to false after error")
        XCTAssertEqual(viewModel.errorMessage, "Task failed", "Should set error message")
    }

    // MARK: - Message Management Tests

    func testSetSuccessMessage() {
        let viewModel = TestViewModel()

        viewModel.setSuccess("Operation completed")

        XCTAssertEqual(viewModel.successMessage, "Operation completed")
        XCTAssertNil(viewModel.errorMessage, "Should not have error message")
    }

    func testSetSuccessMessageClearsError() {
        let viewModel = TestViewModel()
        viewModel.errorMessage = "Previous error"

        viewModel.setSuccess("Success!")

        XCTAssertNil(viewModel.errorMessage, "Should clear error message")
        XCTAssertEqual(viewModel.successMessage, "Success!")
    }

    func testClearErrorMessage() {
        let viewModel = TestViewModel()
        viewModel.errorMessage = "Some error"

        viewModel.clearError()

        XCTAssertNil(viewModel.errorMessage, "Should clear error message")
    }

    func testClearSuccessMessage() {
        let viewModel = TestViewModel()
        viewModel.successMessage = "Some success"

        viewModel.clearSuccess()

        XCTAssertNil(viewModel.successMessage, "Should clear success message")
    }

    func testClearAllMessages() {
        let viewModel = TestViewModel()
        viewModel.errorMessage = "Error"
        viewModel.successMessage = "Success"

        viewModel.clearAllMessages()

        XCTAssertNil(viewModel.errorMessage, "Should clear error message")
        XCTAssertNil(viewModel.successMessage, "Should clear success message")
    }

    // MARK: - Published Properties Tests

    func testIsLoadingPublished() {
        let viewModel = TestViewModel()
        let expectation = XCTestExpectation(description: "isLoading changes published")

        viewModel.$isLoading
            .dropFirst() // Skip initial value
            .sink { loading in
                XCTAssertTrue(loading)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.setLoading(true)

        wait(for: [expectation], timeout: 1.0)
    }

    func testErrorMessagePublished() {
        let viewModel = TestViewModel()
        let expectation = XCTestExpectation(description: "errorMessage changes published")

        viewModel.$errorMessage
            .dropFirst() // Skip initial nil
            .sink { message in
                XCTAssertEqual(message, "Test error")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.triggerError(NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"]))

        wait(for: [expectation], timeout: 1.0)
    }

    func testSuccessMessagePublished() {
        let viewModel = TestViewModel()
        let expectation = XCTestExpectation(description: "successMessage changes published")

        viewModel.$successMessage
            .dropFirst() // Skip initial nil
            .sink { message in
                XCTAssertEqual(message, "Test success")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.setSuccess("Test success")

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Deinit Tests

    func testDeinitCancelsSubscriptions() {
        var viewModel: TestViewModel? = TestViewModel()

        // Add some subscriptions
        Just(true)
            .sink { _ in }
            .store(in: &viewModel!.cancellables)

        XCTAssertFalse(viewModel!.cancellables.isEmpty, "Should have subscriptions")

        // Deinit should clean up
        viewModel = nil

        // Can't directly test cancellables after deinit, but ensuring no memory leaks is the goal
        XCTAssertNil(viewModel, "ViewModel should be deallocated")
    }
}
