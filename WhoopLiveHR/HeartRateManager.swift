import Foundation
import Combine
import CoreBluetooth


// MARK: - Models

struct HeartRateSample: Identifiable {

    let id = UUID()

    let timestamp: Date

    let bpm: Int
}


// MARK: - HeartRateManager

final class HeartRateManager: NSObject, ObservableObject {

    // MARK: Published state

    @Published private(set) var heartRate: Int?

    @Published private(set) var status: String =
        "Starting Bluetooth..."

    @Published private(set) var deviceName: String =
        "WHOOP"

    @Published private(set) var rssi: Int?

    @Published private(set) var lastUpdatedAt: Date?

    @Published private(set) var isConnected = false

    @Published private(set) var bluetoothState:
        CBManagerState = .unknown

    @Published private(set) var history:
        [HeartRateSample] = []


    // MARK: CoreBluetooth

    private var centralManager: CBCentralManager!

    private var whoopPeripheral: CBPeripheral?


    // MARK: Timers

    private var staleHeartRateTimer: Timer?

    private var scanFallbackTimer: Timer?

    private var rssiTimer: Timer?


    // MARK: BLE UUIDs

    private let heartRateService =
        CBUUID(string: "180D")

    private let heartRateMeasurement =
        CBUUID(string: "2A37")


    // MARK: Configuration

    private let staleReadingTimeout:
        TimeInterval = 10

    private let scanFallbackDelay:
        TimeInterval = 5

    private let reconnectDelay:
        TimeInterval = 2

    private let historyDuration:
        TimeInterval = 5 * 60

    private let rssiRefreshInterval:
        TimeInterval = 10


    // MARK: Internal state

    private var isShuttingDown = false

    private var isUsingBroadScan = false


    // MARK: Init

    override init() {
        super.init()

        /*
         queue: nil means CoreBluetooth callbacks
         arrive on the main queue.

         That's convenient because our @Published
         properties drive the UI directly.
         */
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil
        )

        startStaleHeartRateTimer()
    }


    deinit {
        invalidateTimers()
    }


    // MARK: Public API

    func shutdown() {

        isShuttingDown = true

        invalidateTimers()

        if centralManager.isScanning {
            centralManager.stopScan()
        }

        if let whoopPeripheral {
            centralManager.cancelPeripheralConnection(
                whoopPeripheral
            )
        }
    }


    // MARK: Scanning

    private func startTargetedScan() {

        guard !isShuttingDown else {
            return
        }

        guard centralManager.state == .poweredOn else {
            return
        }

        stopScanning()

        isUsingBroadScan = false

        status = "Scanning for WHOOP..."

        print(
            "Starting targeted WHOOP scan for Heart Rate service..."
        )

        centralManager.scanForPeripherals(
            withServices: [
                heartRateService
            ],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey:
                    false
            ]
        )

        scheduleBroadScanFallback()
    }


    private func startBroadScan() {

        guard !isShuttingDown else {
            return
        }

        guard centralManager.state == .poweredOn else {
            return
        }

        stopScanning()

        isUsingBroadScan = true

        status = "Searching for WHOOP..."

        print(
            "Targeted scan found nothing. Starting broad BLE scan..."
        )

        /*
         Fallback for WHOOP firmware/device variants
         that may not advertise 180D in the advertisement.
         */
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey:
                    false
            ]
        )
    }


    private func stopScanning() {

        scanFallbackTimer?.invalidate()

        scanFallbackTimer = nil

        guard centralManager?.isScanning == true else {
            return
        }

        centralManager.stopScan()
    }


    private func scheduleBroadScanFallback() {

        scanFallbackTimer?.invalidate()

        scanFallbackTimer =
            Timer.scheduledTimer(
                withTimeInterval: scanFallbackDelay,
                repeats: false
            ) { [weak self] _ in

                guard let self else {
                    return
                }

                guard self.whoopPeripheral == nil else {
                    return
                }

                guard !self.isShuttingDown else {
                    return
                }

                self.startBroadScan()
            }
    }


    // MARK: Reconnection

    private func scheduleReconnect() {

        guard !isShuttingDown else {
            return
        }

        status =
            "WHOOP disconnected. Reconnecting..."

        DispatchQueue.main.asyncAfter(
            deadline: .now() + reconnectDelay
        ) { [weak self] in

            guard let self else {
                return
            }

            guard !self.isShuttingDown else {
                return
            }

            self.startTargetedScan()
        }
    }


    // MARK: Heart rate state

    private func resetHeartRate() {

        heartRate = nil

        lastUpdatedAt = nil

        rssi = nil
    }


    private func updateHeartRate(
        _ bpm: Int
    ) {

        let now = Date()

        heartRate = bpm

        lastUpdatedAt = now

        status = "Receiving heart rate"

        history.append(
            HeartRateSample(
                timestamp: now,
                bpm: bpm
            )
        )

        pruneHistory(
            relativeTo: now
        )
    }


    private func pruneHistory(
        relativeTo now: Date
    ) {

        let cutoff =
            now.addingTimeInterval(
                -historyDuration
            )

        history.removeAll {
            $0.timestamp < cutoff
        }
    }


    // MARK: Stale reading protection

    private func startStaleHeartRateTimer() {

        staleHeartRateTimer =
            Timer.scheduledTimer(
                withTimeInterval: 2,
                repeats: true
            ) { [weak self] _ in

                self?.checkForStaleHeartRate()
            }
    }


    private func checkForStaleHeartRate() {

        guard let lastUpdatedAt else {
            return
        }

        let elapsed =
            Date().timeIntervalSince(
                lastUpdatedAt
            )

        guard elapsed > staleReadingTimeout else {
            return
        }

        guard heartRate != nil else {
            return
        }

        print(
            "Heart-rate reading became stale"
        )

        heartRate = nil

        if isConnected {
            status =
                "Connected, waiting for heart rate..."
        }
    }


    // MARK: RSSI

    private func startRSSITimer() {

        rssiTimer?.invalidate()

        rssiTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    rssiRefreshInterval,
                repeats: true
            ) { [weak self] _ in

                guard
                    let self,
                    let peripheral =
                        self.whoopPeripheral,
                    peripheral.state ==
                        .connected
                else {
                    return
                }

                peripheral.readRSSI()
            }
    }


    // MARK: Timers

    private func invalidateTimers() {

        staleHeartRateTimer?.invalidate()

        staleHeartRateTimer = nil

        scanFallbackTimer?.invalidate()

        scanFallbackTimer = nil

        rssiTimer?.invalidate()

        rssiTimer = nil
    }


    // MARK: WHOOP identification

    private func isWhoopDevice(
        name: String
    ) -> Bool {

        let normalized =
            name.uppercased()

        return
            normalized.contains("WHOOP")
            || normalized.hasPrefix("WHP")
    }


    // MARK: HR packet parsing

    private func parseHeartRate(
        _ data: Data
    ) -> Int? {

        guard data.count >= 2 else {
            return nil
        }

        let flags = data[0]

        /*
         Bluetooth Heart Rate Measurement:

         bit 0 == 0 → UINT8
         bit 0 == 1 → UINT16
         */
        let is16Bit =
            (flags & 0x01) != 0

        if is16Bit {

            guard data.count >= 3 else {
                return nil
            }

            let value =
                UInt16(data[1])
                |
                (
                    UInt16(data[2])
                    << 8
                )

            return Int(value)
        }

        return Int(data[1])
    }
}


// MARK: - CBCentralManagerDelegate

extension HeartRateManager:
    CBCentralManagerDelegate {

    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {

        bluetoothState =
            central.state

        switch central.state {

        case .poweredOn:

            print(
                "Bluetooth is powered on"
            )

            startTargetedScan()


        case .poweredOff:

            print(
                "Bluetooth is powered off"
            )

            stopScanning()

            isConnected = false

            resetHeartRate()

            status =
                "Bluetooth is off"


        case .unauthorized:

            print(
                "Bluetooth access is unauthorized"
            )

            stopScanning()

            isConnected = false

            resetHeartRate()

            status =
                "Bluetooth permission denied"


        case .unsupported:

            stopScanning()

            isConnected = false

            resetHeartRate()

            status =
                "Bluetooth unsupported"


        case .resetting:

            stopScanning()

            isConnected = false

            resetHeartRate()

            status =
                "Bluetooth resetting..."


        case .unknown:

            status =
                "Bluetooth state unknown"


        @unknown default:

            status =
                "Unknown Bluetooth state"
        }
    }


    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData:
            [String: Any],
        rssi RSSI: NSNumber
    ) {

        let advertisedName =
            advertisementData[
                CBAdvertisementDataLocalNameKey
            ] as? String

        let name =
            advertisedName
            ?? peripheral.name
            ?? "Unknown"


        /*
         During the broad fallback scan there may
         be many devices, so don't spam the console.
         */
        if !isUsingBroadScan
            || isWhoopDevice(name: name) {

            print(
                "Discovered: \(name) | RSSI: \(RSSI)"
            )
        }


        guard isWhoopDevice(name: name) else {
            return
        }


        print(
            "Found WHOOP: \(name)"
        )

        stopScanning()

        deviceName = name

        rssi =
            RSSI.intValue

        status =
            "WHOOP found. Connecting..."

        whoopPeripheral =
            peripheral

        peripheral.delegate =
            self

        central.connect(
            peripheral,
            options: nil
        )
    }


    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {

        print(
            "Connected to WHOOP"
        )

        isConnected = true

        status =
            "Connected to WHOOP"

        peripheral.delegate =
            self

        peripheral.discoverServices(
            [
                heartRateService
            ]
        )

        peripheral.readRSSI()

        startRSSITimer()
    }


    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral:
            CBPeripheral,
        error: Error?
    ) {

        print(
            "Failed to connect: "
            +
            (
                error?.localizedDescription
                ?? "unknown error"
            )
        )

        isConnected = false

        whoopPeripheral = nil

        resetHeartRate()

        scheduleReconnect()
    }


    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral:
            CBPeripheral,
        error: Error?
    ) {

        print(
            "WHOOP disconnected"
        )

        if let error {

            print(
                "Disconnect reason: "
                +
                error.localizedDescription
            )
        }

        rssiTimer?.invalidate()

        rssiTimer = nil

        isConnected = false

        whoopPeripheral = nil

        resetHeartRate()

        scheduleReconnect()
    }
}


// MARK: - CBPeripheralDelegate

extension HeartRateManager:
    CBPeripheralDelegate {

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {

        if let error {

            print(
                "Service discovery failed: "
                +
                error.localizedDescription
            )

            status =
                "Failed to discover services"

            return
        }


        guard
            let services =
                peripheral.services
        else {
            return
        }


        guard
            let heartService =
                services.first(
                    where: {
                        $0.uuid ==
                            heartRateService
                    }
                )
        else {

            print(
                "Heart Rate service not found"
            )

            status =
                "Heart Rate service unavailable"

            return
        }


        print(
            "Found Heart Rate service"
        )

        peripheral.discoverCharacteristics(
            [
                heartRateMeasurement
            ],
            for: heartService
        )
    }


    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service:
            CBService,
        error: Error?
    ) {

        if let error {

            print(
                "Characteristic discovery failed: "
                +
                error.localizedDescription
            )

            status =
                "Failed to discover heart-rate characteristic"

            return
        }


        guard
            let characteristics =
                service.characteristics
        else {
            return
        }


        guard
            let characteristic =
                characteristics.first(
                    where: {
                        $0.uuid ==
                            heartRateMeasurement
                    }
                )
        else {

            status =
                "Heart Rate characteristic unavailable"

            return
        }


        print(
            "Found Heart Rate Measurement"
        )

        status =
            "Waiting for heart rate..."

        peripheral.setNotifyValue(
            true,
            for: characteristic
        )
    }


    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor
            characteristic:
                CBCharacteristic,
        error: Error?
    ) {

        if let error {

            print(
                "Failed to enable HR notifications: "
                +
                error.localizedDescription
            )

            status =
                "Failed to subscribe to heart rate"

            return
        }


        guard
            characteristic.uuid ==
                heartRateMeasurement
        else {
            return
        }


        print(
            "Heart-rate notifications enabled: "
            +
            "\(characteristic.isNotifying)"
        )
    }


    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic:
            CBCharacteristic,
        error: Error?
    ) {

        if let error {

            print(
                "Heart-rate update failed: "
                +
                error.localizedDescription
            )

            return
        }


        guard
            characteristic.uuid ==
                heartRateMeasurement
        else {
            return
        }


        guard
            let data =
                characteristic.value
        else {
            return
        }


        guard
            let bpm =
                parseHeartRate(data)
        else {

            print(
                "Unable to parse heart-rate packet"
            )

            return
        }


        updateHeartRate(bpm)
    }


    func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {

        if let error {

            print(
                "Failed to read RSSI: "
                +
                error.localizedDescription
            )

            return
        }

        rssi =
            RSSI.intValue
    }
}
