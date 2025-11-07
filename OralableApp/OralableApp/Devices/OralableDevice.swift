class OralableDevice {
    let connectionManager: BLEConnectionManager
    let dataParser = BLEDataParser.self
    let characteristicManager: BLECharacteristicManager?
    let notificationHandler: BLENotificationHandler
    let stateManager: BLEStateManager
    
    init() {
        connectionManager = BLEConnectionManager()
        notificationHandler = BLENotificationHandler()
        stateManager = BLEStateManager()
    }
}
