//
//  DevicesViewModel.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 26.09.2025.
//

import CoreBluetooth

enum SplitPart {
    case left
    case right
}

struct Part: Hashable {
    let id: String
    let type: SplitPart
}

@Observable
final class DevicesViewModel: NSObject {
    
    var connectedDevices: [CBPeripheral] = []
    var batteryLevel: String {
        get {
            // icons
            // battery.0percent
            // battery.25percent
            // battery.50percent
            // battery.75percent
            // battery.100percent
            
            if peripheral == nil {
                return "Select device"
            }
            
            if splitPartsLevels.count == 1, let onlyOne = splitPartsLevels.getFirst(part: .left) {
                return "\(onlyOne)%"
            } else if splitPartsLevels.count == 2,
                      let left = splitPartsLevels.getFirst(part: .left),
                      let right = splitPartsLevels.getFirst(part: .right) {
                return "L: \(left)% | R: \(right)%"
            } else {
                return "Disconnected"
            }
        }
    }
    
    private var splitPartsLevels: [Part: Int] = [:]
    
    private let batteryServiceCBUUID = CBUUID(string: "0x180F")
    private let batteryLevelCharacteristicCBUUID = CBUUID(string: "0x2A19")
    
    private var peripheral: CBPeripheral?
    
    private var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func getConnectedDevices() {
        connectedDevices = centralManager.retrieveConnectedPeripherals(withServices: [batteryServiceCBUUID])
    }
    
    func selectDevice(_ peripheral: CBPeripheral) {
        self.splitPartsLevels = [:]
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheral)
    }
}

// MARK: - Bluetooth manager delegate

extension DevicesViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            // TODO: make it user friendly
            assertionFailure("Bluetooth is turned off")
        default:
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([batteryServiceCBUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        splitPartsLevels = [:]
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
            splitPartsLevels[part] = 0
        } else if services.count == 2 {
            let left = Part(id: "\(uuid)-\(services.first!.hash)", type: .left)
            let right = Part(id: "\(uuid)-\(services.last!.hash)", type: .right)
            
            splitPartsLevels[left] = 0
            splitPartsLevels[right] = 0
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
            guard let value = characteristic.value else {
                return
            }
            
            guard let partKey = splitPartsLevels.keys.first(where: { $0.id == partId }) else {
                return
            }
            
            splitPartsLevels[partKey] = Int(value.uint8)
        default:
            break
        }
    }
}
