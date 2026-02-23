//
//  TranscriberError.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

nonisolated enum TranscriberError: LocalizedError {

    case unavailable

    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .unavailable: "Speech recognition is not available"
        case .permissionDenied: "Speech recognition permission denied"
        }
    }
}
