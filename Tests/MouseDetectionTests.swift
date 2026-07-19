import Foundation

@main
struct MouseDetectionTests {
    static func main() {
        var failures: [String] = []

        testBluetoothTransport(failures: &failures)
        testVirtualHIDMouseMatrix(failures: &failures)
        testVirtualIOBluetoothMatrix(failures: &failures)
        testBluetoothEventLoggingScope(failures: &failures)
        testNegativeMatrix(failures: &failures)

        if failures.isEmpty {
            let liveNames = BluetoothMouseDetector().connectedMouseNames()
            let liveSummary = liveNames.isEmpty ? "none" : liveNames.joined(separator: ", ")
            print("MouseDetectionTests passed: virtual device matrix + live detector")
            print("Live detected Bluetooth mice: \(liveSummary)")
        } else {
            fputs(failures.joined(separator: "\n") + "\n", stderr)
            exit(1)
        }
    }

    private static func testBluetoothTransport(failures: inout [String]) {
        for transport in ["Bluetooth", "Bluetooth Low Energy", "Bluetooth LE"] {
            expect(
                BluetoothMouseClassifier.isBluetoothTransport(transport),
                "\(transport) transport should be accepted",
                failures: &failures
            )
        }
    }

    private static func testVirtualHIDMouseMatrix(failures: inout [String]) {
        let products = [
            "Generic BT5.2 Mouse",
            "Rechargeable Bluetooth Mouse",
            "Bluetooth 5.0 Mouse",
            "Logitech Pebble",
            "Logitech Pebble M350",
            "Logi M650",
            "Logitech M720",
            "MX Anywhere 3",
            "MX Anywhere 3S",
            "MX Master 2S",
            "MX Master 3",
            "MX Master 3S",
            "MX Vertical",
            "MX Ergo",
            "Logi Lift",
            "Magic Mouse",
            "Microsoft Bluetooth Mouse",
            "Surface Mobile Mouse",
            "Rapoo M100",
            "Xiaomi Mi Dual Mode Wireless Mouse",
            "Lenovo ThinkPad Bluetooth Silent Mouse",
            "HP Bluetooth Travel Mouse",
            "ELECOM Bluetooth Mouse",
            "Razer Pro Click Mini",
            "ProtoArc EM01 NL",
            "Unknown HID Mouse"
        ]

        for transport in ["Bluetooth", "Bluetooth Low Energy"] {
            for product in products {
                expect(
                    BluetoothMouseClassifier.isHIDMouse(
                        transport: transport,
                        productName: product,
                        primaryUsagePage: 1,
                        primaryUsage: 2
                    ),
                    "HID \(transport) mouse should be accepted: \(product)",
                    failures: &failures
                )
            }
        }

        expect(
            BluetoothMouseClassifier.isHIDMouse(
                transport: "Bluetooth Low Energy",
                productName: nil,
                primaryUsagePage: 1,
                primaryUsage: 2
            ),
            "Unknown-name BLE HID mouse should be accepted for low-cost devices",
            failures: &failures
        )
    }

    private static func testVirtualIOBluetoothMatrix(failures: inout [String]) {
        let pointingPeripheralClass = UInt32(0x05 << 8) | UInt32(0x20 << 2)
        let namedFallbacks = [
            "Generic Bluetooth Mouse",
            "BT5.2 Mouse",
            "Logitech Pebble",
            "Logi M650",
            "MX Anywhere 3S",
            "MX Master 3S",
            "M720 Triathlon",
            "M590",
            "M350 Pebble"
        ]

        for name in namedFallbacks {
            expect(
                BluetoothMouseClassifier.isBluetoothDeviceMouse(name: name, classOfDevice: 0),
                "IOBluetooth named fallback should be accepted: \(name)",
                failures: &failures
            )
        }

        expect(
            BluetoothMouseClassifier.isBluetoothDeviceMouse(
                name: "Unknown Peripheral",
                classOfDevice: pointingPeripheralClass
            ),
            "IOBluetooth pointing peripheral class should be accepted without name hints",
            failures: &failures
        )
    }

    private static func testNegativeMatrix(failures: inout [String]) {
        expect(
            !BluetoothMouseClassifier.isHIDMouse(
                transport: "USB",
                productName: "Logitech Pebble",
                primaryUsagePage: 1,
                primaryUsage: 2
            ),
            "USB HID mouse should not trigger Bluetooth mouse mode",
            failures: &failures
        )

        expect(
            !BluetoothMouseClassifier.isHIDMouse(
                transport: "Bluetooth Low Energy",
                productName: "Magic Trackpad",
                primaryUsagePage: 1,
                primaryUsage: 2
            ),
            "Bluetooth trackpads should stay in trackpad mode",
            failures: &failures
        )

        expect(
            !BluetoothMouseClassifier.isHIDMouse(
                transport: "Bluetooth Low Energy",
                productName: "Bluetooth Keyboard",
                primaryUsagePage: 1,
                primaryUsage: 6
            ),
            "Bluetooth keyboards should not be treated as mice",
            failures: &failures
        )

        expect(
            !BluetoothMouseClassifier.isHIDMouse(
                transport: "Bluetooth Low Energy",
                productName: "AirPods Pro",
                primaryUsagePage: 12,
                primaryUsage: 1
            ),
            "Bluetooth audio controls should not be treated as mice",
            failures: &failures
        )

        expect(
            !BluetoothMouseClassifier.isBluetoothDeviceMouse(
                name: "AirPods Pro",
                classOfDevice: 0x240418
            ),
            "Audio devices should not be treated as mice",
            failures: &failures
        )
    }

    private static func testBluetoothEventLoggingScope(failures: inout [String]) {
        let pointingPeripheralClass = UInt32(0x05 << 8) | UInt32(0x20 << 2)

        expect(
            BluetoothMouseClassifier.bluetoothMouseEventLabel(
                name: "Magic Mouse",
                address: "AA-BB-CC-DD-EE-FF",
                classOfDevice: pointingPeripheralClass
            ) == "Magic Mouse",
            "Mouse events should prefer the mouse name",
            failures: &failures
        )

        expect(
            BluetoothMouseClassifier.bluetoothMouseEventLabel(
                name: nil,
                address: "AA-BB-CC-DD-EE-FF",
                classOfDevice: pointingPeripheralClass
            ) == "AA-BB-CC-DD-EE-FF",
            "Unnamed mouse events should fall back to the Bluetooth address",
            failures: &failures
        )

        expect(
            BluetoothMouseClassifier.bluetoothMouseEventLabel(
                name: "AirPods Pro",
                address: "11-22-33-44-55-66",
                classOfDevice: 0x240418
            ) == nil,
            "Non-mouse Bluetooth identifiers should not enter the event log",
            failures: &failures
        )
    }

    private static func expect(_ condition: Bool, _ message: String, failures: inout [String]) {
        if !condition {
            failures.append("FAIL: \(message)")
        }
    }
}
