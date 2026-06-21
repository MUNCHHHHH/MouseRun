import Cocoa
import IOBluetooth
import Darwin

private enum ScrollDirection: String {
    case naturalOn = "on"
    case naturalOff = "off"
}

private enum AppStatus: Equatable {
    case trackpadMode
    case mouseMode([String])
    case error(String)
}

private final class EventLog {
    private let key = "recentEvents"
    private let limit = 50

    func add(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let entry = "\(formatter.string(from: Date())) \(message)"
        var events = UserDefaults.standard.stringArray(forKey: key) ?? []
        events.append(entry)
        if events.count > limit {
            events = Array(events.suffix(limit))
        }
        UserDefaults.standard.set(events, forKey: key)
    }

    func all() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}

private final class NaturalScrollController {
    private let log: EventLog
    private let privateScrollAPI = PrivateScrollDirectionAPI()

    init(log: EventLog) {
        self.log = log
    }

    func current() -> Bool {
        if let current = privateScrollAPI.current() {
            return current
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "-g", "com.apple.swipescrolldirection"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value == "1" || value?.lowercased() == "true"
        } catch {
            log.add("Failed to read natural scroll setting: \(error.localizedDescription)")
            return true
        }
    }

    @discardableResult
    func set(_ direction: ScrollDirection) -> Bool {
        let enabled = direction == .naturalOn
        if let apiResult = privateScrollAPI.set(enabled) {
            if apiResult {
                log.add("Natural scrolling \(enabled ? "enabled" : "disabled") via PreferencePanesSupport")
            } else {
                log.add("PreferencePanesSupport failed to set natural scrolling")
            }
            return apiResult
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = [
            "write",
            "-g",
            "com.apple.swipescrolldirection",
            "-bool",
            enabled ? "true" : "false"
        ]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                flushPreferences()
                log.add("Natural scrolling \(enabled ? "enabled" : "disabled")")
                return true
            }
            log.add("defaults write failed with status \(task.terminationStatus)")
            return false
        } catch {
            log.add("Failed to set natural scroll setting: \(error.localizedDescription)")
            return false
        }
    }

    private func flushPreferences() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["cfprefsd"]
        try? task.run()
    }
}

private final class PrivateScrollDirectionAPI {
    private typealias SwipeScrollDirectionFunction = @convention(c) () -> Int32
    private typealias SetSwipeScrollDirectionFunction = @convention(c) (Int32) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let readFunction: SwipeScrollDirectionFunction?
    private let setFunction: SetSwipeScrollDirectionFunction?

    init() {
        let path = "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/Versions/A/PreferencePanesSupport"
        handle = dlopen(path, RTLD_NOW)

        if let handle {
            if let readSymbol = dlsym(handle, "swipeScrollDirection") {
                readFunction = unsafeBitCast(readSymbol, to: SwipeScrollDirectionFunction.self)
            } else {
                readFunction = nil
            }

            if let setSymbol = dlsym(handle, "setSwipeScrollDirection") {
                setFunction = unsafeBitCast(setSymbol, to: SetSwipeScrollDirectionFunction.self)
            } else {
                setFunction = nil
            }
        } else {
            readFunction = nil
            setFunction = nil
        }
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    func current() -> Bool? {
        guard let readFunction else { return nil }
        return readFunction() != 0
    }

    @discardableResult
    func set(_ enabled: Bool) -> Bool? {
        guard let readFunction, let setFunction else { return nil }
        let currentValue = readFunction() != 0
        guard currentValue != enabled else { return true }
        setFunction(enabled ? 1 : 0)
        usleep(150_000)
        return (readFunction() != 0) == enabled
    }
}

private final class BluetoothMouseDetector {
    func connectedMouseNames() -> [String] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return devices
            .filter { $0.isConnected() }
            .filter { isMouse($0) }
            .compactMap { device in
                let name = device.nameOrAddress ?? device.addressString
                return name?.isEmpty == false ? name : nil
            }
            .sorted()
    }

    private func isMouse(_ device: IOBluetoothDevice) -> Bool {
        let name = (device.nameOrAddress ?? "").lowercased()

        if name.contains("trackpad") ||
            name.contains("keyboard") ||
            name.contains("headphone") ||
            name.contains("airpods") ||
            name.contains("speaker") {
            return false
        }

        let classOfDevice = UInt32(device.classOfDevice)
        let majorDeviceClass = (classOfDevice >> 8) & 0x1f
        let peripheralMinorClass = (classOfDevice >> 2) & 0x3f
        let isPeripheral = majorDeviceClass == 0x05
        let hasPointingBit = (peripheralMinorClass & 0x20) != 0

        if isPeripheral && hasPointingBit {
            return true
        }

        let mouseNameHints = [
            "mouse",
            "magic mouse",
            "mx anywhere",
            "mx master",
            "logitech",
            "m720",
            "m650",
            "m590",
            "m350",
            "pebble"
        ]
        return mouseNameHints.contains { name.contains($0) }
    }
}

private final class LoginItemInstaller {
    private let label = "com.munch.mouserun"
    private let log: EventLog

    init(log: EventLog) {
        self.log = log
    }

    var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    func installIfPossible() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            log.add("Skipped login item install outside app bundle")
            return
        }

        let executablePath = Bundle.main.executablePath ?? "/Applications/MouseRun.app/Contents/MacOS/MouseRun"
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        do {
            let directory = launchAgentURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try plist.write(to: launchAgentURL, atomically: true, encoding: .utf8)
            log.add("Login item installed")
        } catch {
            log.add("Failed to install login item: \(error.localizedDescription)")
        }
    }
}

private final class MouseIconFactory {
    func stoppedIcon() -> NSImage {
        loadIcon(named: "MouseStopped")
    }

    func runningIcons() -> [NSImage] {
        (1...4).map { loadIcon(named: "MouseRun\($0)") }
    }

    private func loadIcon(named name: String) -> NSImage {
        guard let image = NSImage(named: name) else {
            let fallback = NSImage(size: NSSize(width: 28, height: 20))
            fallback.isTemplate = true
            return fallback
        }
        image.size = NSSize(width: 30, height: 20)
        image.isTemplate = true
        return image
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let log = EventLog()
    private lazy var scrollController = NaturalScrollController(log: log)
    private let detector = BluetoothMouseDetector()
    private lazy var loginInstaller = LoginItemInstaller(log: log)
    private let iconFactory = MouseIconFactory()

    private var backupTimer: Timer?
    private var animationTimer: Timer?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [IOBluetoothUserNotification] = []
    private var runningIcons: [NSImage] = []
    private var runningFrame = 0
    private var status: AppStatus = .trackpadMode

    private let statusMenuItem = NSMenuItem(title: "상태 확인 중", action: nil, keyEquivalent: "")
    private let scrollMenuItem = NSMenuItem(title: "자연스러운 스크롤: 확인 중", action: nil, keyEquivalent: "")
    private let deviceMenuItem = NSMenuItem(title: "감지된 마우스 없음", action: nil, keyEquivalent: "")
    private let troubleshootingMenuItem = NSMenuItem(title: "문제 해결 정보 복사", action: #selector(copyTroubleshootingInfo), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isOnlyRunningInstance() else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        runningIcons = iconFactory.runningIcons()
        setupMenu()
        loginInstaller.installIfPossible()
        registerBluetoothNotifications()
        synchronize(reason: "app launch")
        backupTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.synchronize(reason: "backup check")
        }
        log.add("MouseRun started")
    }

    private func isOnlyRunningInstance() -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.munch.mouserun")
        return !runningApps.contains { $0.processIdentifier != currentPID }
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        backupTimer?.invalidate()
        connectNotification?.unregister()
        disconnectNotifications.forEach { $0.unregister() }
        _ = scrollController.set(.naturalOn)
        log.add("MouseRun terminated; natural scrolling enabled")
    }

    private func setupMenu() {
        statusMenuItem.isEnabled = false
        scrollMenuItem.isEnabled = false
        deviceMenuItem.isEnabled = false
        troubleshootingMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(scrollMenuItem)
        menu.addItem(deviceMenuItem)
        menu.addItem(.separator())
        menu.addItem(troubleshootingMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self

        statusItem.menu = menu
        statusItem.button?.image = iconFactory.stoppedIcon()
        statusItem.button?.toolTip = "MouseRun"
    }

    private func registerBluetoothNotifications() {
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        refreshDisconnectNotifications()
    }

    private func refreshDisconnectNotifications() {
        disconnectNotifications.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        for device in devices where device.isConnected() {
            if let notification = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:))) {
                disconnectNotifications.append(notification)
            }
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        log.add("Bluetooth device connected: \(device.nameOrAddress ?? device.addressString ?? "Unknown")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshDisconnectNotifications()
            self.synchronize(reason: "connect event")
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        log.add("Bluetooth device disconnected: \(device.nameOrAddress ?? device.addressString ?? "Unknown")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshDisconnectNotifications()
            self.synchronize(reason: "disconnect event")
        }
    }

    private func synchronize(reason: String) {
        let previousStatus = status
        let mice = detector.connectedMouseNames()
        let target: ScrollDirection = mice.isEmpty ? .naturalOn : .naturalOff
        let shouldBeNatural = target == .naturalOn
        let isAlreadyCorrect = scrollController.current() == shouldBeNatural
        let success = isAlreadyCorrect || scrollController.set(target)

        if success {
            status = mice.isEmpty ? .trackpadMode : .mouseMode(mice)
            if status != previousStatus || reason != "backup check" {
                log.add("Synchronized from \(reason): \(mice.isEmpty ? "trackpad mode" : mice.joined(separator: ", "))")
            }
        } else {
            status = .error("스크롤 설정 변경 실패")
        }

        updateMenu()
        updateAnimation()
    }

    private func updateMenu() {
        switch status {
        case .trackpadMode:
            statusMenuItem.title = "상태: 트랙패드 모드"
            deviceMenuItem.title = "감지된 블루투스 마우스 없음"
        case .mouseMode(let mice):
            statusMenuItem.title = "상태: 블루투스 마우스 연결됨"
            deviceMenuItem.title = "마우스: \(mice.joined(separator: ", "))"
        case .error(let message):
            statusMenuItem.title = "상태: \(message)"
            deviceMenuItem.title = "쥐가 멈춰 있으면 이 메뉴를 확인해 주세요"
        }

        scrollMenuItem.title = "자연스러운 스크롤: \(scrollController.current() ? "켜짐" : "꺼짐")"
        statusItem.button?.toolTip = statusMenuItem.title
    }

    private func updateAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil

        guard case .mouseMode = status else {
            statusItem.button?.image = iconFactory.stoppedIcon()
            return
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statusItem.button?.image = self.runningIcons[self.runningFrame % self.runningIcons.count]
            self.runningFrame += 1
        }
        animationTimer?.fire()
    }

    @objc private func copyTroubleshootingInfo() {
        let info = [
            "MouseRun troubleshooting",
            "Publisher: MUNCH",
            "Status: \(statusMenuItem.title)",
            "Natural scrolling: \(scrollController.current() ? "on" : "off")",
            "Detected mice: \(detector.connectedMouseNames().joined(separator: ", "))",
            "LaunchAgent: \(loginInstaller.launchAgentURL.path)",
            "Recent events:",
            log.all().joined(separator: "\n")
        ].joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
