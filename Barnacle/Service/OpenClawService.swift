//
//  OpenClawService.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

enum OpenClawService {

    static func sendMessage(
        _ text: String,
        gatewayURL: String,
        token: String
    ) async throws -> String {
        guard let url = URL(string: "\(gatewayURL)/hooks/agent") else {
            throw OpenClawError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "message": text,
            "deliver": false
        ])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenClawError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenClawError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw OpenClawError.unauthorized
        default:
            throw OpenClawError.serverError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reply = json["response"] as? String ?? json["message"] as? String ?? json["text"] as? String
        else {
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                return raw
            }
            throw OpenClawError.decodingError
        }
        return reply
    }

    static func validateConnection(gatewayURL: String) async throws {
        guard let url = URL(string: "\(gatewayURL)/hooks") else {
            throw OpenClawError.invalidURL
        }
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) else {
            throw OpenClawError.networkError(URLError(.cannotConnectToHost))
        }
    }

    static func validateAuth(gatewayURL: String, token: String) async throws {
        _ = try await sendMessage("ping", gatewayURL: gatewayURL, token: token)
    }
}
