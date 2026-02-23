//
//  TextChunkBuffer.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Foundation

struct TextChunkBuffer {

    private static let sentenceBoundaries: Set<Character> = [".", "!", "?", ";", ":", "\n"]

    private var buffer = ""

    mutating func add(_ text: String) -> [String] {
        buffer += text
        var chunks: [String] = []

        while let index = findLastBoundary() {
            let splitIndex = buffer.index(after: index)
            let chunk = String(buffer[buffer.startIndex..<splitIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if hasSpeakableContent(chunk) {
                chunks.append(chunk)
            }
            buffer = String(buffer[splitIndex...])
        }

        return chunks
    }

    mutating func flush() -> String? {
        let remainder = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return hasSpeakableContent(remainder) ? remainder : nil
    }

    private func hasSpeakableContent(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        }
    }

    private func findLastBoundary() -> String.Index? {
        var lastBoundary: String.Index?
        for index in buffer.indices {
            if Self.sentenceBoundaries.contains(buffer[index]) {
                lastBoundary = index
            }
        }
        return lastBoundary
    }
}
