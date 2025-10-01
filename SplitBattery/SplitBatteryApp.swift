//
//  SplitBatteryApp.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 25.09.2025.
//

import SwiftUI

@main
struct SplitBatteryApp: App {
    
    @State
    private var viewModel = DevicesViewModel()
    
    var body: some Scene {
        MenuBarExtra(viewModel.batteryLevel) {
            ContentView()
                .environment(viewModel)
        }
        .menuBarExtraStyle(.menu)
    }
}
