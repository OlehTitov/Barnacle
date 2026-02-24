//
//  TranscriptionEngine.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import Foundation

enum TranscriptionEngine: String, CaseIterable {

    case apple

    case whisper

    var label: String {
        switch self {
        case .apple: "Apple"
        case .whisper: "Whisper"
        }
    }
}
