//
//  OpenClawError.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

enum OpenClawError: LocalizedError {

    case invalidURL

    case unauthorized

    case serverError(Int)

    case networkError(Error)

    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid gateway URL"
        case .unauthorized: "Invalid or expired token"
        case .serverError(let code): "Server error (\(code))"
        case .networkError(let error): error.localizedDescription
        case .decodingError: "Failed to parse response"
        }
    }
}
