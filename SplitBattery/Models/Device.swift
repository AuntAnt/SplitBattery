//
//  Device.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 02.10.2025.
//

import Foundation

struct Device {
    var leftPart: Part
    var rightPart: Part?
}

enum SplitPart {
    case left
    case right
}

struct Part: Hashable {
    let id: String
    let type: SplitPart
    var level: Int?
}
