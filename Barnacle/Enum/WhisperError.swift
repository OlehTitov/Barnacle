//
//  WhisperError.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import Foundation

enum WhisperError: LocalizedError {

    case invalidAPIKey

    case apiError(Int)

    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            "Invalid OpenAI API key"
        case .apiError(let code):
            "OpenAI API error (\(code))"
        case .decodingError:
            "Failed to decode transcription response"
        }
    }
}
