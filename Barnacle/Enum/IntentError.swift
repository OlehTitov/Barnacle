//
//  IntentError.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import Foundation

enum IntentError: LocalizedError {

    case microphonePermissionDenied

    case missingCredentials

    case conversationFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required"
        case .missingCredentials:
            return "Please configure Barnacle credentials first"
        case .conversationFailed(let reason):
            return reason
        }
    }
}
