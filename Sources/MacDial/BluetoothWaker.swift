import Foundation
import CoreBluetooth

/// Makes the dial reconnect quickly after it wakes from sleep.
///
/// When the Surface Dial sits idle it drops its Bluetooth link and goes to
/// sleep. Pressing or turning it wakes it up and it starts advertising again,
/// but macOS only looks for bonded HID devices with a slow background scan, so
/// it can take several seconds before the link (and the HID device we read
/// from) comes back.
///
/// Holding a pending CoreBluetooth connection to the dial tells the Mac's
/// Bluetooth controller we want it *now*: the controller watches for the
/// dial's advertisements itself and connects on the first one it hears, which
/// typically brings the dial back in a few hundred milliseconds.
///
/// This costs the dial nothing. All the listening happens on the Mac's side;
/// we never keep the link alive, poll the dial, or stop it from sleeping. When
/// the dial disconnects to sleep we simply re-arm the pending connection and
/// wait. If anything it saves the dial a little battery, because it spends
/// less time advertising before the Mac picks it up.
final class BluetoothWaker: NSObject, CBCentralManagerDelegate {
    private static let identifierKey = "dialPeripheralIdentifier"
    /// HID over GATT, Battery, Device Information. Any of these finds the dial
    /// among the peripherals the system already has connected.
    private static let dialServices = [CBUUID(string: "1812"), CBUUID(string: "180F"), CBUUID(string: "180A")]

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    /// Call when the HID device appears, so we can learn which Bluetooth
    /// peripheral is the dial if we don't know yet.
    func dialDidAttach() {
        guard isEnabled, peripheral?.state != .connected else { return }
        findDial()
    }

    // MARK: - Lifecycle

    private func start() {
        guard central == nil else { return }
        // Creating the manager asks for Bluetooth permission the first time.
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    private func stop() {
        if let peripheral, let central {
            // Only drops our claim on the link; the system's HID connection,
            // if any, carries on as normal.
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        central?.delegate = nil
        central = nil
    }

    private func findDial() {
        guard let central, central.state == .poweredOn else { return }

        // Prefer a dial that's connected right now (handles re-pairing, which
        // gives it a new identifier), then fall back to the one we saw last.
        var candidate = central.retrieveConnectedPeripherals(withServices: Self.dialServices)
            .first { ($0.name ?? "").localizedCaseInsensitiveContains("Surface Dial") }
        if candidate == nil,
           let saved = UserDefaults.standard.string(forKey: Self.identifierKey),
           let uuid = UUID(uuidString: saved) {
            candidate = central.retrievePeripherals(withIdentifiers: [uuid]).first
        }
        guard let candidate else { return }

        if let old = peripheral, old != candidate {
            central.cancelPeripheralConnection(old)
        }
        UserDefaults.standard.set(candidate.identifier.uuidString, forKey: Self.identifierKey)
        peripheral = candidate
        arm()
    }

    /// A pending connect never times out. It sits in the controller until the
    /// dial advertises, then connects straight away.
    private func arm() {
        guard let central, let peripheral, central.state == .poweredOn else { return }
        central.connect(peripheral, options: nil)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if peripheral == nil { findDial() } else { arm() }
        case .unauthorized, .unsupported:
            NSLog("MacDial: Bluetooth unavailable for fast wake (state %d)", central.state.rawValue)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // The dial went to sleep (or out of range). Wait for it to come back.
        guard peripheral == self.peripheral else { return }
        arm()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        // Don't spin if the dial was unpaired: re-arm after a pause.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.arm() }
    }
}
