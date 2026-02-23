//
//  SSEParser.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

struct SSEParser {

    private var currentEvent = ""
    private var currentData = ""

    mutating func parseLine(_ line: String) -> SSEEvent? {
        if line.isEmpty {
            return flushEvent()
        }

        if line.hasPrefix("event:") {
            // A new event: line means the previous event is complete.
            // bytes.lines skips blank lines, so we flush here instead.
            let previous = flushEvent()
            currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return previous
        } else if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if !currentData.isEmpty {
                currentData += "\n"
            }
            currentData += value
        }

        return nil
    }

    private mutating func flushEvent() -> SSEEvent? {
        guard !currentEvent.isEmpty || !currentData.isEmpty else {
            return nil
        }

        defer {
            currentEvent = ""
            currentData = ""
        }

        if currentData == "[DONE]" {
            return .done
        }

        switch currentEvent {
        case "response.output_text.delta":
            return extractDelta(from: currentData).map { .textDelta($0) }

        case "response.output_text.done":
            return extractText(from: currentData).map { .textDone($0) }

        case "response.completed":
            return .done

        default:
            return nil
        }
    }

    private func extractDelta(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = json["delta"] as? String
        else {
            return nil
        }
        return delta
    }

    private func extractText(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String
        else {
            return nil
        }
        return text
    }
}
