import Foundation
import IOBluetooth
import IOKit.hid

enum BluetoothMouseClassifier {
    static func isBluetoothDeviceMouse(name: String, classOfDevice: UInt32) -> Bool {
        let normalizedName = name.lowercased()

        if isRejectedBluetoothDeviceName(normalizedName) {
            return false
        }

        let majorDeviceClass = (classOfDevice >> 8) & 0x1f
        let peripheralMinorClass = (classOfDevice >> 2) & 0x3f
        let isPeripheral = majorDeviceClass == 0x05
        let hasPointingBit = (peripheralMinorClass & 0x20) != 0

        if isPeripheral && hasPointingBit {
            return true
        }

        return hasMouseNameHint(normalizedName)
    }

    static func isHIDMouse(
        transport: String?,
        productName: String?,
        primaryUsagePage: Int?,
        primaryUsage: Int?
    ) -> Bool {
        guard isBluetoothTransport(transport),
              primaryUsagePage == kHIDPage_GenericDesktop,
              primaryUsage == kHIDUsage_GD_Mouse else {
            return false
        }

        let normalizedName = (productName ?? "").lowercased()
        return !isRejectedHIDMouseName(normalizedName)
    }

    static func isBluetoothTransport(_ transport: String?) -> Bool {
        guard let transport else { return false }
        return transport.lowercased().contains("bluetooth")
    }

    static func bluetoothMouseEventLabel(
        name: String?,
        address: String?,
        classOfDevice: UInt32
    ) -> String? {
        let displayName = trimmed(name)
        guard isBluetoothDeviceMouse(
            name: displayName ?? "",
            classOfDevice: classOfDevice
        ) else {
            return nil
        }

        return displayName ?? trimmed(address) ?? "Unknown Bluetooth mouse"
    }

    private static func trimmed(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedValue, !trimmedValue.isEmpty else { return nil }
        return trimmedValue
    }

    private static func isRejectedBluetoothDeviceName(_ name: String) -> Bool {
        rejectedBluetoothNameFragments.contains { name.contains($0) }
    }

    private static func isRejectedHIDMouseName(_ name: String) -> Bool {
        rejectedHIDMouseNameFragments.contains { name.contains($0) }
    }

    private static func hasMouseNameHint(_ name: String) -> Bool {
        mouseNameHints.contains { name.contains($0) }
    }

    private static let rejectedBluetoothNameFragments = [
        "trackpad",
        "touchpad",
        "keyboard",
        "headphone",
        "headset",
        "airpods",
        "earbuds",
        "speaker"
    ]

    private static let rejectedHIDMouseNameFragments = [
        "trackpad",
        "touchpad"
    ]

    private static let mouseNameHints = [
        "mouse",
        "magic mouse",
        "mx anywhere",
        "mx master",
        "logi",
        "logitech",
        "m720",
        "m650",
        "m590",
        "m350",
        "pebble"
    ]
}

final class BluetoothMouseDetector {
    private let hidManager: IOHIDManager
    private var hidChangeHandler: (() -> Void)?
    private var hidMonitoringStarted = false

    init() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(hidManager, Self.hidMouseMatchingDictionaries as CFArray)
    }

    deinit {
        stopHIDMonitoring()
    }

    func connectedMouseNames() -> [String] {
        var names = Set<String>()
        connectedIOBluetoothMouseNames().forEach { names.insert($0) }
        connectedHIDMouseNames().forEach { names.insert($0) }
        return names.sorted()
    }

    func startHIDMonitoring(onChange: @escaping () -> Void) {
        hidChangeHandler = onChange

        guard !hidMonitoringStarted else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, Self.hidDeviceChanged, context)
        IOHIDManagerRegisterDeviceRemovalCallback(hidManager, Self.hidDeviceChanged, context)
        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidMonitoringStarted = true
    }

    func stopHIDMonitoring() {
        guard hidMonitoringStarted else { return }
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidMonitoringStarted = false
        hidChangeHandler = nil
    }

    private func connectedIOBluetoothMouseNames() -> [String] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return devices
            .filter { $0.isConnected() }
            .filter { device in
                let name = device.nameOrAddress ?? ""
                return BluetoothMouseClassifier.isBluetoothDeviceMouse(
                    name: name,
                    classOfDevice: UInt32(device.classOfDevice)
                )
            }
            .compactMap { displayName(name: $0.nameOrAddress, fallback: $0.addressString) }
    }

    private func connectedHIDMouseNames() -> [String] {
        guard let devices = IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice> else {
            return []
        }

        return devices
            .filter { Self.isBluetoothHIDMouse($0) }
            .compactMap { displayName(name: Self.stringProperty(kIOHIDProductKey, from: $0), fallback: nil) }
    }

    private func handleHIDDeviceChanged(_ device: IOHIDDevice) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.hidChangeHandler?()
        }
    }

    private func displayName(name: String?, fallback: String?) -> String? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedFallback, !trimmedFallback.isEmpty {
            return trimmedFallback
        }

        return nil
    }

    private static let hidMouseMatchingDictionaries: [[String: Int]] = [
        [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse
        ]
    ]

    private static let hidDeviceChanged: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        let detector = Unmanaged<BluetoothMouseDetector>.fromOpaque(context).takeUnretainedValue()
        detector.handleHIDDeviceChanged(device)
    }

    private static func isBluetoothHIDMouse(_ device: IOHIDDevice) -> Bool {
        BluetoothMouseClassifier.isHIDMouse(
            transport: stringProperty(kIOHIDTransportKey, from: device),
            productName: stringProperty(kIOHIDProductKey, from: device),
            primaryUsagePage: intProperty(kIOHIDPrimaryUsagePageKey, from: device),
            primaryUsage: intProperty(kIOHIDPrimaryUsageKey, from: device)
        )
    }

    private static func stringProperty(_ key: String, from device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func intProperty(_ key: String, from device: IOHIDDevice) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber {
            return number.intValue
        }

        return nil
    }
}
