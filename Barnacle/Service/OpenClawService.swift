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
        guard let url = URL(string: "\(gatewayURL)/v1/responses") else {
            throw OpenClawError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("agent:main:main", forHTTPHeaderField: "x-openclaw-session-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input": text,
            "model": "openclaw:main",
            "instructions": "User is speaking via voice. Respond conversationally — short, direct, no markdown formatting, no bullet lists, no asterisks. Write like you're talking, not typing."
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
        case 429:
            throw OpenClawError.serverError(429)
        default:
            throw OpenClawError.serverError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenClawError.decodingError
        }

        if json["error"] is [String: Any] {
            throw OpenClawError.serverError(httpResponse.statusCode)
        }

        return extractOutputText(from: json)
    }

    static func streamMessage(
        _ text: String,
        gatewayURL: String,
        token: String
    ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        guard let url = URL(string: "\(gatewayURL)/v1/responses") else {
            throw OpenClawError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("agent:main:main", forHTTPHeaderField: "x-openclaw-session-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input": text,
            "model": "openclaw:main",
            "stream": true,
            "instructions": "User is speaking via voice. Respond conversationally — short, direct, no markdown formatting, no bullet lists, no asterisks. Write like you're talking, not typing."
        ])

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
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
        case 429:
            throw OpenClawError.serverError(429)
        default:
            throw OpenClawError.serverError(httpResponse.statusCode)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                var parser = SSEParser()

                do {
                    for try await line in bytes.lines {
                        if let event = parser.parseLine(line) {
                            continuation.yield(event)
                            if case .done = event { break }
                        }
                    }

                    if let event = parser.parseLine("") {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func validateConnection(gatewayURL: String) async throws {
        guard let url = URL(string: "\(gatewayURL)/v1/responses") else {
            throw OpenClawError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "openclaw",
            "input": "ping"
        ])

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenClawError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenClawError.networkError(URLError(.cannotConnectToHost))
        }

        guard (200...499).contains(http.statusCode) else {
            throw OpenClawError.networkError(URLError(.cannotConnectToHost))
        }
    }

    static func validateAuth(gatewayURL: String, token: String) async throws {
        _ = try await sendMessage("ping", gatewayURL: gatewayURL, token: token)
    }

    private static func extractOutputText(from json: [String: Any]) -> String {
        // OpenResponses format: { "output": [ { "type": "message", "content": [ { "type": "output_text", "text": "..." } ] } ] }
        if let output = json["output"] as? [[String: Any]] {
            let texts: [String] = output.compactMap { item in
                guard let content = item["content"] as? [[String: Any]] else { return nil }
                return content.compactMap { part in
                    part["text"] as? String
                }.joined()
            }
            let result = texts.joined()
            if !result.isEmpty { return result }
        }

        // Fallback: check common top-level keys
        if let text = json["output_text"] as? String { return text }
        if let text = json["response"] as? String { return text }
        if let text = json["text"] as? String { return text }

        return "No response"
    }
}
