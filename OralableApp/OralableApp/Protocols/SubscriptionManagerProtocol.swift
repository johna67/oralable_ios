//
//  SubscriptionManagerProtocol.swift
//  OralableApp
//
//  Purpose: Protocol for SubscriptionManager to enable dependency injection and testing
//

import Foundation
import StoreKit
import Combine

@MainActor
protocol SubscriptionManagerProtocol: AnyObject, ObservableObject {
    // MARK: - Published Properties
    var currentTier: SubscriptionTier { get }
    var isPaidSubscriber: Bool { get }
    var availableProducts: [Product] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get set }
    var subscriptionExpiryDate: Date? { get set }
    var showExpiryWarning: Bool { get }

    // MARK: - Publishers
    var currentTierPublisher: AnyPublisher<SubscriptionTier, Never> { get }
    var isPaidSubscriberPublisher: AnyPublisher<Bool, Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }

    // MARK: - Product Loading
    func loadProducts() async

    // MARK: - Purchase Flow
    func purchase(_ product: Product) async throws

    // MARK: - Restore Purchases
    func restorePurchases() async throws

    // MARK: - Subscription Status
    func updateSubscriptionStatus() async

    // MARK: - Feature Access
    func hasAccess(to feature: String) -> Bool
    func canShareWithMultipleProfessionals() -> Bool
    func hasAdvancedAnalytics() -> Bool
    func hasUnlimitedExport() -> Bool
    func maxProfessionalShares() -> Int

    // MARK: - Product Information
    func product(for identifier: String) -> Product?
    var monthlyProduct: Product? { get }
    var yearlyProduct: Product? { get }

    // MARK: - Expiry Status
    var isExpiringSoon: Bool { get }
    var daysUntilExpiry: Int { get }
    var hasExpired: Bool { get }
    var expiryWarningMessage: String? { get }
    func checkExpiryStatus()
}

// MARK: - Default Publisher Implementation

extension SubscriptionManager: SubscriptionManagerProtocol {
    var currentTierPublisher: AnyPublisher<SubscriptionTier, Never> {
        $currentTier.eraseToAnyPublisher()
    }

    var isPaidSubscriberPublisher: AnyPublisher<Bool, Never> {
        $isPaidSubscriber.eraseToAnyPublisher()
    }

    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
}
