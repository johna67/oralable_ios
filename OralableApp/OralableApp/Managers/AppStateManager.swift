import Foundation
import Combine

@MainActor
class AppStateManager: ObservableObject {
    // Patient app is always in subscription mode
    @Published var selectedMode: AppMode? = .subscription

    // Never needs mode selection
    var needsModeSelection: Bool {
        return false
    }

    init() {}

    // Mode management not needed for patient app, but keep for compatibility
    func setMode(_ mode: AppMode) {
        selectedMode = mode
    }

    func clearMode() {
        // Do nothing - patient app doesn't change modes
    }
}
