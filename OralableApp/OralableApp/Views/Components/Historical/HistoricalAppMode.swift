import Foundation

// MARK: - App Mode and Subscription Management
enum HistoricalAppMode: String, CaseIterable {
    case viewer = "Viewer"
    case subscription = "Subscription"

    var description: String {
        switch self {
        case .viewer:
            return "View historical data with basic analysis"
        case .subscription:
            return "Full access with advanced analytics and sharing"
        }
    }

    var allowsDataSharing: Bool {
        return self == .subscription
    }

    var allowsAdvancedAnalytics: Bool {
        return self == .subscription
    }
}
