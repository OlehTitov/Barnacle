//
//  TranscriptionEngine.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import Foundation

enum TranscriptionEngine: String, CaseIterable {

    case fluid

    case apple

    case scribe

    case whisper

    var label: String {
        switch self {
        case .fluid: "Local (FluidAudio)"
        case .apple: "Apple Speech"
        case .scribe: "ElevenLabs Scribe"
        case .whisper: "OpenAI Whisper"
        }
    }
}
