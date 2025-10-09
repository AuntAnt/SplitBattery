//
//  DevicesViewModel.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 26.09.2025.
//

import CoreBluetooth

@Observable
final class DevicesViewModel: NSObject {
    
    var connectedDevices: [CBPeripheral] = []
    
    var batteryLevel: String {
        get {
            if peripheral == nil {
                return "Select device"
            }
            
            guard let device else {
                return "Waiting..."
            }
            
            let left = device.leftPart.level.map({ "\($0.description)%" }) ?? "?"
            let right = device.rightPart?.level.map({ "\($0.description)%" }) ?? "?"
            
            return "L: \(left) | R: \(right)"
        }
    }
    
    private var device: Device?
    
    private let batteryServiceCBUUID = CBUUID(string: "0x180F")
    private let batteryLevelCharacteristicCBUUID = CBUUID(string: "0x2A19")
    private let savedDeviceKey = "selected_peripheral"
    
    private var peripheral: CBPeripheral?
    
    private var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func getConnectedDevices() {
        connectedDevices = centralManager.retrieveConnectedPeripherals(withServices: [batteryServiceCBUUID])
        
        if let peripheralUuid = UserDefaults.standard.object(forKey: savedDeviceKey) as? String,
           let savedPeripheral = connectedDevices.first(where: { $0.identifier.uuidString == peripheralUuid }) {
            self.peripheral = savedPeripheral
            self.peripheral?.delegate = self
            centralManager.connect(savedPeripheral)
        }
    }
    
    func selectDevice(_ peripheral: CBPeripheral) {
        self.device = nil
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: savedDeviceKey)
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        centralManager.connect(peripheral)
    }
}

// MARK: - Bluetooth manager delegate

extension DevicesViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let peripheral {
                central.connect(peripheral)
            } else {
                getConnectedDevices()
            }
        default:
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([batteryServiceCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        device = nil
        
        // when device is disconnected kick scanning for it,
        // if it is gone into standby mode, wait for to wake up
        central.scanForPeripherals(withServices: [batteryServiceCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // if disconnected device found again, automatically connecting to it and stop scanning
        if peripheral == self.peripheral {
            central.stopScan()
            central.connect(peripheral)
        }
    }
}

// MARK: - Peripheral delegate

extension DevicesViewModel: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let services = peripheral.services else {
            return
        }
        
        let uuid = peripheral.identifier.uuidString
        
        if services.count == 1 {
            let part = Part(id: "\(uuid)-\(services.first!.hash)", type: .left)
            self.device = Device(leftPart: part, rightPart: nil)
        } else if services.count == 2 {
            let left = Part(id: "\(uuid)-\(services.first!.hash)", type: .left)
            let right = Part(id: "\(uuid)-\(services.last!.hash)", type: .right)
            
            self.device = Device(leftPart: left, rightPart: right)
        } else {
            assertionFailure("Found \(services.count) services, it is not handled yet")
        }
        
        services.forEach {
            peripheral.discoverCharacteristics([batteryLevelCharacteristicCBUUID], for: $0)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        guard let characteristics = service.characteristics else {
            return
        }
        
        // 2 characteristics here for left and right parts
        characteristics.forEach { characteristic in
            if characteristic.properties.contains(.read) {
                // goes to didUpdateValueFor characteristic
                peripheral.readValue(for: characteristic)
            }
            
            if characteristic.properties.contains(.notify) {
                // goes to didUpdateValueFor characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard let service = characteristic.service else {
            return
        }
        
        let partId = "\(peripheral.identifier.uuidString)-\(service.hash)"
        
        switch characteristic.uuid {
        case batteryLevelCharacteristicCBUUID:
            let value = characteristic.value?.first.map(Int.init)
            
            if device?.leftPart.id == partId {
                device?.leftPart.level = value
            } else if device?.rightPart?.id == partId {
                device?.rightPart?.level = value
            }
        default:
            break
        }
    }
}
