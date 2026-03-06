//
//  AudioRoutingMode.swift
//  Barnacle
//
//  Created by Codex on 06.03.2026.
//

enum AudioRoutingMode: String, CaseIterable {

    case nativeCarBluetooth

    case bluetoothAdapter

    var label: String {
        switch self {
        case .nativeCarBluetooth:
            "Native car Bluetooth"
        case .bluetoothAdapter:
            "BT adapter (iPhone mic)"
        }
    }

    var helperText: String {
        switch self {
        case .nativeCarBluetooth:
            "Use the car's Bluetooth hands-free profile for both audio output and microphone when available."
        case .bluetoothAdapter:
            "Use Bluetooth audio output only and keep recording from the iPhone microphone."
        }
    }
}
