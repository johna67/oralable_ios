//
//  BaseViewModel.swift
//  OralableApp
//
//  Created: Phase 1 Refactoring
//  Base class for all ViewModels to reduce code duplication
//

import Foundation
import Combine
import SwiftUI

/// Base class for all ViewModels providing common functionality
@MainActor
class BaseViewModel: ObservableObject {

    // MARK: - Common Published Properties

    /// Indicates if the ViewModel is currently performing an operation
    @Published var isLoading = false

    /// Error message to display to the user
    @Published var errorMessage: String?

    /// Success message to display to the user
    @Published var successMessage: String?

    // MARK: - Common Properties

    /// Set of cancellables for Combine subscriptions
    var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        Logger.shared.debug("[\(type(of: self))] Initialized")
    }

    deinit {
        Logger.shared.debug("[\(type(of: self))] Deinitialized")
        cancellables.removeAll()
    }

    // MARK: - Error Handling

    /// Handle an error by logging it and setting the error message
    /// - Parameter error: The error to handle
    func handleError(_ error: Error) {
        let errorDescription = error.localizedDescription
        Logger.shared.error("[\(type(of: self))] Error: \(errorDescription)")
        errorMessage = errorDescription
        isLoading = false
    }

    /// Clear the current error message
    func clearError() {
        errorMessage = nil
    }

    /// Clear the current success message
    func clearSuccess() {
        successMessage = nil
    }

    /// Clear all messages (error and success)
    func clearAllMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Loading State Management

    /// Execute an async task with automatic loading state management
    /// - Parameter task: The async task to execute
    func withLoading(_ task: @escaping () async throws -> Void) async {
        isLoading = true
        clearAllMessages()

        do {
            try await task()
            isLoading = false
        } catch {
            handleError(error)
        }
    }

    /// Execute an async task with automatic loading state management and success message
    /// - Parameters:
    ///   - successMessage: Message to display on success
    ///   - task: The async task to execute
    func withLoading(successMessage: String, _ task: @escaping () async throws -> Void) async {
        isLoading = true
        clearAllMessages()

        do {
            try await task()
            self.successMessage = successMessage
            isLoading = false
            Logger.shared.info("[\(type(of: self))] Success: \(successMessage)")
        } catch {
            handleError(error)
        }
    }

    // MARK: - Lifecycle Methods

    /// Called when the view appears
    /// Override in subclasses to add custom behavior
    func onAppear() {
        Logger.shared.debug("[\(type(of: self))] View appeared")
    }

    /// Called when the view disappears
    /// Override in subclasses to add custom behavior
    func onDisappear() {
        Logger.shared.debug("[\(type(of: self))] View disappeared")
    }

    /// Reset the ViewModel to its initial state
    /// Override in subclasses to add custom reset logic
    func reset() {
        isLoading = false
        clearAllMessages()
        Logger.shared.debug("[\(type(of: self))] Reset to initial state")
    }
}

// MARK: - ViewModifier for Error/Success Display

extension View {
    /// Display error and success alerts from a BaseViewModel
    /// - Parameter viewModel: The ViewModel to observe
    /// - Returns: Modified view with alert presentation
    func handleViewModelAlerts<VM: BaseViewModel>(_ viewModel: VM) -> some View {
        self
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.clearSuccess()
                }
            } message: {
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                }
            }
    }
}
