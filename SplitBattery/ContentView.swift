//
//  ContentView.swift
//  SplitBattery
//
//  Created by Anton Kuzmin on 25.09.2025.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(DevicesViewModel.self)
    private var viewModel
    
    var body: some View {
        VStack {
            Section {
                ForEach(viewModel.connectedDevices, id: \.self) { device in
                    Button(
                        action: {
                            viewModel.selectDevice(device)
                        },
                        label: {
                            Text(device.name ?? "Unknown")
                        }
                    )
                }
            }
            
            Section {
                Button(
                    action: {
                        viewModel.getConnectedDevices()
                    },
                    label: {
                        Text("Refresh devices list")
                    }
                )
            }
            
            Section {
                Button(
                    action: {
                        NSApplication.shared.terminate(nil)
                    },
                    label: {
                        Text("Quit")
                    }
                )
            }
        }
        .onAppear {
            viewModel.getConnectedDevices()
        }
    }
}

#Preview {
    ContentView()
}
