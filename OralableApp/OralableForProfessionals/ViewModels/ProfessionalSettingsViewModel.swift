import Foundation
import Combine
import StoreKit

@MainActor
class ProfessionalSettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentTier: ProfessionalSubscriptionTier = .starter
    @Published var isSubscriptionActive: Bool = false
    @Published var subscriptionExpiryDate: Date?
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var showingUpgradeSheet: Bool = false
    @Published var errorMessage: String?
    @Published var professionalName: String?
    @Published var professionalEmail: String?

    // MARK: - Dependencies

    private let subscriptionManager: ProfessionalSubscriptionManager
    private let authenticationManager: ProfessionalAuthenticationManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var subscriptionStatus: String {
        if currentTier == .starter {
            return "Free Plan"
        }
        return isSubscriptionActive ? "Active" : "Inactive"
    }

    var subscriptionDetails: String {
        guard let expiryDate = subscriptionExpiryDate else {
            return "No expiration"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Renews on \(formatter.string(from: expiryDate))"
    }

    // MARK: - Initialization

    init(subscriptionManager: ProfessionalSubscriptionManager, authenticationManager: ProfessionalAuthenticationManager) {
        self.subscriptionManager = subscriptionManager
        self.authenticationManager = authenticationManager

        // Subscribe to subscription manager updates
        subscriptionManager.$currentTier
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTier)

        subscriptionManager.$isSubscriptionActive
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSubscriptionActive)

        subscriptionManager.$subscriptionExpiryDate
            .receive(on: DispatchQueue.main)
            .assign(to: &$subscriptionExpiryDate)

        subscriptionManager.$availableProducts
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableProducts)

        subscriptionManager.$purchaseInProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPurchasing)

        subscriptionManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)

        // Subscribe to authentication manager updates
        authenticationManager.$userFullName
            .receive(on: DispatchQueue.main)
            .assign(to: &$professionalName)

        authenticationManager.$userEmail
            .receive(on: DispatchQueue.main)
            .assign(to: &$professionalEmail)
    }

    // MARK: - Actions

    func showUpgrade() {
        showingUpgradeSheet = true
    }

    func purchaseSubscription(_ product: Product) async {
        do {
            try await subscriptionManager.purchase(product)
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        await subscriptionManager.restorePurchases()
    }

    func signOut() {
        authenticationManager.signOut()
    }

    func clearError() {
        errorMessage = nil
    }

    func loadProducts() async {
        await subscriptionManager.loadProducts()
    }
}
