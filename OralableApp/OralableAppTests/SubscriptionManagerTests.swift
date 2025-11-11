//
//  SubscriptionManagerTests.swift
//  OralableAppTests
//
//  Created: November 11, 2025
//  Testing SubscriptionManager functionality
//

import XCTest
import StoreKit
@testable import OralableApp

@MainActor
class SubscriptionManagerTests: XCTestCase {

    var subscriptionManager: SubscriptionManager!

    override func setUp() async throws {
        try await super.setUp()
        // Note: We're using the shared instance for these tests
        // In a production app, you'd want to inject a mock for better isolation
        subscriptionManager = SubscriptionManager.shared

        // Clear saved state
        UserDefaults.standard.removeObject(forKey: "subscriptionTier")

        // Reset to basic for testing
        #if DEBUG
        subscriptionManager.resetToBasic()
        #endif
    }

    override func tearDown() async throws {
        subscriptionManager = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(subscriptionManager.currentTier, .basic)
        XCTAssertFalse(subscriptionManager.isPaidSubscriber)
    }

    // MARK: - Subscription Tier Tests

    func testSubscriptionTierDisplayNames() {
        XCTAssertEqual(SubscriptionTier.basic.displayName, "Basic (Free)")
        XCTAssertEqual(SubscriptionTier.paid.displayName, "Premium")
    }

    func testSubscriptionTierFeatures() {
        // Basic tier should have features
        let basicFeatures = SubscriptionTier.basic.features
        XCTAssertFalse(basicFeatures.isEmpty)
        XCTAssertTrue(basicFeatures.contains { $0.contains("Connect to TGM device") })

        // Paid tier should have more features
        let paidFeatures = SubscriptionTier.paid.features
        XCTAssertFalse(paidFeatures.isEmpty)
        XCTAssertTrue(paidFeatures.contains { $0.contains("All Basic features") })
        XCTAssertTrue(paidFeatures.contains { $0.contains("Unlimited data export") })
        XCTAssertTrue(paidFeatures.contains { $0.contains("Cloud backup") })
    }

    // MARK: - Feature Access Tests

    func testFeatureAccessBasicTier() {
        // Ensure we're on basic tier
        #if DEBUG
        subscriptionManager.resetToBasic()
        #endif

        // Basic tier should not have access to premium features
        XCTAssertFalse(subscriptionManager.hasAccess(to: "premiumFeature"))
    }

    func testFeatureAccessPaidTier() {
        #if DEBUG
        // Simulate paid subscription
        subscriptionManager.simulatePurchase()

        // Paid tier should have access to features
        XCTAssertTrue(subscriptionManager.hasAccess(to: "anyFeature"))
        #endif
    }

    // MARK: - Persistence Tests

    func testSubscriptionPersistence() {
        #if DEBUG
        // Given
        subscriptionManager.simulatePurchase()
        XCTAssertTrue(subscriptionManager.isPaidSubscriber)

        // When
        let savedTier = UserDefaults.standard.string(forKey: "subscriptionTier")

        // Then
        XCTAssertEqual(savedTier, SubscriptionTier.paid.rawValue)
        #endif
    }

    // MARK: - Subscription Error Tests

    func testSubscriptionErrorDescriptions() {
        XCTAssertNotNil(SubscriptionError.productNotFound.errorDescription)
        XCTAssertNotNil(SubscriptionError.purchaseFailed.errorDescription)
        XCTAssertNotNil(SubscriptionError.purchaseCancelled.errorDescription)
        XCTAssertNotNil(SubscriptionError.verificationFailed.errorDescription)
        XCTAssertNotNil(SubscriptionError.restoreFailed.errorDescription)

        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        let unknownError = SubscriptionError.unknown(testError)
        XCTAssertNotNil(unknownError.errorDescription)
    }

    // MARK: - Product Identifier Tests

    func testProductIdentifiers() {
        // The subscription manager should have product identifiers defined
        // We can't directly test private properties, but we can test
        // that products will be loaded if available
        XCTAssertFalse(subscriptionManager.availableProducts.isEmpty || subscriptionManager.isLoading,
                      "Products should either be loaded or currently loading")
    }

    // MARK: - Loading State Tests

    func testLoadingState() async {
        // Given
        let initialLoadingState = subscriptionManager.isLoading

        // When
        await subscriptionManager.loadProducts()

        // Then
        // After loading, isLoading should be false
        XCTAssertFalse(subscriptionManager.isLoading)
    }

    // MARK: - Product Access Tests

    func testProductAccess() {
        // These will be nil in test environment without actual App Store Connect products
        // but the methods should work without crashing
        _ = subscriptionManager.monthlyProduct
        _ = subscriptionManager.yearlyProduct
        _ = subscriptionManager.lifetimeProduct

        // No crash = test passes
        XCTAssertTrue(true)
    }

    // MARK: - Reset Functionality Tests

    #if DEBUG
    func testResetToBasic() {
        // Given - start with paid
        subscriptionManager.simulatePurchase()
        XCTAssertTrue(subscriptionManager.isPaidSubscriber)

        // When
        subscriptionManager.resetToBasic()

        // Then
        XCTAssertEqual(subscriptionManager.currentTier, .basic)
        XCTAssertFalse(subscriptionManager.isPaidSubscriber)
    }

    func testSimulatePurchase() {
        // Given
        subscriptionManager.resetToBasic()
        XCTAssertFalse(subscriptionManager.isPaidSubscriber)

        // When
        subscriptionManager.simulatePurchase()

        // Then
        XCTAssertEqual(subscriptionManager.currentTier, .paid)
        XCTAssertTrue(subscriptionManager.isPaidSubscriber)
    }
    #endif

    // MARK: - Subscription Status Update Tests

    func testSubscriptionStatusUpdate() async {
        // This will check current entitlements
        // In test environment, should default to basic
        await subscriptionManager.updateSubscriptionStatus()

        // Should not crash and should have a valid state
        XCTAssertNotNil(subscriptionManager.currentTier)
    }

    // MARK: - Error Message Tests

    func testErrorMessageHandling() {
        // Initially no error
        XCTAssertNil(subscriptionManager.errorMessage)

        // Error message should be settable
        subscriptionManager.errorMessage = "Test error"
        XCTAssertEqual(subscriptionManager.errorMessage, "Test error")

        // Should be clearable
        subscriptionManager.errorMessage = nil
        XCTAssertNil(subscriptionManager.errorMessage)
    }
}
