import Foundation
import IOKit
import IOKit.hid

/// Talks to the Surface Dial directly through IOKit's HID manager.
///
/// Everything is event driven on the main run loop: no polling thread, no busy
/// waiting, so the app idles at ~0% CPU and lets Apple Silicon stay on its
/// efficiency cores.
final class DialDevice {
    enum ButtonState { case pressed, released }

    static let vendorID = 0x045E
    static let productID = 0x091B

    /// Called on the main thread.
    var onButton: ((ButtonState) -> Void)?
    /// Signed detent count, positive = clockwise. Called on the main thread.
    var onRotate: ((Int) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private(set) var isConnected = false
    private(set) var serialNumber = ""
    private(set) var needsInputMonitoringPermission = false

    /// Detents per full revolution reported by the dial (and haptic ticks).
    var stepsPerRevolution = 36 { didSet { pushHapticConfig() } }
    var detentHaptics = false { didSet { pushHapticConfig() } }

    private let manager: IOHIDManager
    private var devices: [IOHIDDevice] = []
    private var reportBuffers: [UnsafeMutablePointer<UInt8>] = []
    private var lastButton = ButtonState.released
    private static let reportBufferSize = 256
    // iokit_common_err(0x2e2): a function-like macro, so not imported into Swift.
    private static let ioReturnNotPermitted = IOReturn(bitPattern: 0xE00002E2)

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    deinit {
        stop()
    }

    func start() {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: DialDevice.vendorID,
            kIOHIDProductIDKey: DialDevice.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DialDevice>.fromOpaque(context).takeUnretainedValue().attach(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DialDevice>.fromOpaque(context).takeUnretainedValue().detach(device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop() {
        // Leave the dial in a sane state for other OSes / apps.
        stepsPerRevolution = 36
        detentHaptics = false
        for device in devices {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        devices.removeAll()
        reportBuffers.forEach { $0.deallocate() }
        reportBuffers.removeAll()
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        setConnected(false)
    }

    // MARK: - Device lifecycle

    private func attach(_ device: IOHIDDevice) {
        guard !devices.contains(where: { $0 === device }) else { return }

        // Seize the device so macOS doesn't also turn the dial into bogus
        // mouse input. Fall back to shared access if seizing isn't allowed.
        var result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if result != kIOReturnSuccess {
            result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if result == DialDevice.ioReturnNotPermitted {
            needsInputMonitoringPermission = true
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            onConnectionChanged?(isConnected)
            return
        }
        guard result == kIOReturnSuccess else {
            NSLog("MacDial: failed to open dial (0x%08x)", result)
            return
        }
        needsInputMonitoringPermission = false

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: DialDevice.reportBufferSize)
        reportBuffers.append(buffer)
        devices.append(device)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, DialDevice.reportBufferSize, { context, _, _, _, reportID, report, length in
            guard let context else { return }
            let bytes = UnsafeBufferPointer(start: report, count: length)
            Unmanaged<DialDevice>.fromOpaque(context).takeUnretainedValue().handleReport(id: reportID, bytes: bytes)
        }, context)

        if let serial = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String {
            serialNumber = serial
        }
        setConnected(true)
        pushHapticConfig()
    }

    private func detach(_ device: IOHIDDevice) {
        guard let index = devices.firstIndex(where: { $0 === device }) else { return }
        devices.remove(at: index)
        reportBuffers.remove(at: index).deallocate()
        if lastButton == .pressed {
            lastButton = .released
            onButton?(.released)
        }
        setConnected(!devices.isEmpty)
    }

    private func setConnected(_ connected: Bool) {
        guard connected != isConnected else { return }
        isConnected = connected
        if !connected { serialNumber = "" }
        onConnectionChanged?(connected)
    }

    // MARK: - Input

    private func handleReport(id: UInt32, bytes: UnsafeBufferPointer<UInt8>) {
        // Report 1: [reportID, buttons, rotation (int8), ...]
        guard bytes.count >= 3, bytes[0] == 1 else { return }

        let button: ButtonState = bytes[1] & 1 == 1 ? .pressed : .released
        let rotation = Int(Int8(bitPattern: bytes[2]))

        if button != lastButton {
            lastButton = button
            onButton?(button)
        }
        if rotation != 0 {
            onRotate?(rotation)
        }
    }

    // MARK: - Haptics
    // Protocol reference: https://github.com/daniel5151/surface-dial-linux/blob/main/src/dial_device/haptics.rs

    private func pushHapticConfig() {
        let steps = max(1, min(stepsPerRevolution, 3600))
        let report: [UInt8] = [
            0x01,                              // report ID
            UInt8(steps & 0xff),               // steps per revolution (lo)
            UInt8((steps >> 8) & 0xff),        // steps per revolution (hi)
            0x00,                              // repeat count
            detentHaptics ? 0x03 : 0x02,       // auto trigger on/off
            0x00,                              // waveform cutoff time
            0x00, 0x00,                        // retrigger period
        ]
        send(report, type: kIOHIDReportTypeFeature)
    }

    /// Fires a single haptic click (used for menu ticks and confirmations).
    func buzz(repeatCount: UInt8 = 0) {
        let report: [UInt8] = [
            0x01,           // report ID
            repeatCount,
            0x03,           // manual trigger
            0x00, 0x00,     // retrigger period
        ]
        send(report, type: kIOHIDReportTypeOutput)
    }

    private func send(_ report: [UInt8], type: IOHIDReportType) {
        for device in devices {
            report.withUnsafeBufferPointer { ptr in
                _ = IOHIDDeviceSetReport(device, type, CFIndex(report[0]), ptr.baseAddress!, ptr.count)
            }
        }
    }
}
