//
//  Transcriber.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import Speech

@Observable
final class Transcriber {

    private(set) var partialResult: String = ""

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func transcribe(request: SFSpeechAudioBufferRecognitionRequest) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriberError.unavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result {
                    self?.partialResult = result.bestTranscription.formattedString
                    if result.isFinal {
                        guard !hasResumed else { return }
                        hasResumed = true
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                } else if let error {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        partialResult = ""
    }
}
