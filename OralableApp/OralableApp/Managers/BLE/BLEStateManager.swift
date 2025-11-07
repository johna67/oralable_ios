import Foundation
import Combine

enum BLEState {
    case poweredOff
    case poweredOn
    case scanning
    case connecting
    case connected
    case disconnected
    case error(String)
}

class BLEStateManager: ObservableObject {
    @Published var currentState: BLEState = .poweredOff
    @Published var errorMessage: String?
    
    func setState(_ state: BLEState) {
        currentState = state
        if case .error(let message) = state {
            errorMessage = message
        }
    }
}
