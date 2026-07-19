import Foundation

enum EventLogPrivacy {
    private static let legacyUnscopedBluetoothMarkers = [
        "Bluetooth device connected:",
        "Bluetooth device disconnected:"
    ]

    static func removingLegacyUnscopedBluetoothEvents(from events: [String]) -> [String] {
        events.filter { event in
            !legacyUnscopedBluetoothMarkers.contains { event.contains($0) }
        }
    }
}
