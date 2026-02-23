//
//  TTSError.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

enum TTSError: LocalizedError {

    case invalidVoiceID

    case apiError

    var errorDescription: String? {
        switch self {
        case .invalidVoiceID: "Invalid voice ID"
        case .apiError: "Text-to-speech API error"
        }
    }
}
