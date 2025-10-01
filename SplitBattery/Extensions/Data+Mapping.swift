//
//  Data+Mapping.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 28.09.2025.
//

import Foundation

extension Data {
    var uint8: UInt8 {
        get {
            var number: UInt8 = 0
            self.copyBytes(to:&number, count: MemoryLayout<UInt8>.size)
            return number
        }
    }
}
