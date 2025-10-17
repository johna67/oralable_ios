import Foundation
import StoreKit

enum SubscriptionTier: String, Codable {
    case basic = "basic"
    case paid = "paid"
    
    var displayName: String {
        switch self {
        case .basic:
            return "Basic (Free)"
        case .paid:
            return "Premium"
        }
    }
    
    var features: [String] {
        switch self {
        case .basic:
            return [
                "Connect to TGM device",
                "View real-time sensor data",
                "Export data logs (limited)",
                "Basic data visualization"
            ]
        case .paid:
            return [
                "All Basic features",
                "Unlimited data export",
                "Advanced analytics",
                "Historical data tracking",
                "Cloud backup",
                "Premium support",
                "Future premium features"
            ]
        }
    }
}

class SubscriptionManager: ObservableObject {
    @Published var currentTier: SubscriptionTier = .basic
    @Published var isPaidSubscriber = false
    
    static let shared = SubscriptionManager()
    
    private init() {
        loadSubscriptionStatus()
    }
    
    // Load subscription status from UserDefaults
    private func loadSubscriptionStatus() {
        if let tierString = UserDefaults.standard.string(forKey: "subscriptionTier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            self.currentTier = tier
            self.isPaidSubscriber = (tier == .paid)
        }
    }
    
    // Save subscription status
    private func saveSubscriptionStatus() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: "subscriptionTier")
    }
    
    // Check if feature is available for current tier
    func hasAccess(to feature: String) -> Bool {
        switch currentTier {
        case .basic:
            return false // Can add specific basic features check here
        case .paid:
            return true
        }
    }
    
    // Upgrade to paid (placeholder for future StoreKit integration)
    func upgradeToPaid(completion: @escaping (Bool) -> Void) {
        // TODO: Implement StoreKit purchase flow
        // For now, this is a placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.currentTier = .paid
            self.isPaidSubscriber = true
            self.saveSubscriptionStatus()
            completion(true)
        }
    }
    
    // Restore purchases (placeholder for future StoreKit integration)
    func restorePurchases(completion: @escaping (Bool) -> Void) {
        // TODO: Implement StoreKit restore
        completion(false)
    }
    
    // Reset to basic tier
    func resetToBasic() {
        currentTier = .basic
        isPaidSubscriber = false
        saveSubscriptionStatus()
    }
}
