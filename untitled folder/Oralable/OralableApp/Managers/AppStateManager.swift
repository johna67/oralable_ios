import Foundation
import Combine

@MainActor
class AppStateManager: ObservableObject {
    // MARK: - Dependency Injection (Phase 4: Singleton Removed)
    // Note: Use AppDependencies.shared.appStateManager instead

    // Patient app is always in subscription mode
    @Published var selectedMode: HistoricalAppMode? = .subscription

    // Never needs mode selection
    var needsModeSelection: Bool {
        return false
    }

    init() {}

    // Mode management not needed for patient app, but keep for compatibility
    func setMode(_ mode: HistoricalAppMode) {
        selectedMode = mode
    }

    func clearMode() {
        // Do nothing - patient app doesn't change modes
    }
}
