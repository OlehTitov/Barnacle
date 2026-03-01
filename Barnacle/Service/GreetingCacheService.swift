//
//  GreetingCacheService.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import AVFoundation
import Foundation

enum GreetingCacheService {

    static var cachedFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("greeting.mp3")
    }

    static var isCached: Bool {
        FileManager.default.fileExists(atPath: cachedFileURL.path)
    }

    static func ensureCached(config: TTSConfig) async throws {
        guard !isCached else { return }

        let greetingText = "Boom, I'm here"
        let request: URLRequest

        switch config.provider {
        case .elevenLabs:
            guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(config.voiceID)") else {
                throw TTSError.invalidVoiceID
            }
            var r = URLRequest(url: url)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")
            r.httpBody = try JSONSerialization.data(withJSONObject: [
                "text": greetingText,
                "model_id": config.modelID,
                "voice_settings": [
                    "stability": config.stability,
                    "similarity_boost": config.similarityBoost,
                    "style": config.style
                ]
            ])
            request = r

        case .openAI:
            guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
                throw TTSError.apiError
            }
            var r = URLRequest(url: url)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("Bearer \(config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
            var body: [String: Any] = [
                "model": "gpt-4o-mini-tts",
                "input": greetingText,
                "voice": config.openAIVoice,
                "response_format": "mp3",
                "speed": config.openAISpeed
            ]
            if !config.openAIVoiceInstructions.isEmpty {
                body["instructions"] = config.openAIVoiceInstructions
            }
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            request = r
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw TTSError.apiError
        }

        try data.write(to: cachedFileURL)
    }

    static func playGreeting() async throws {
        let player = try AVAudioPlayer(contentsOf: cachedFileURL)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let delegate = AudioPlayerFinishDelegate {
                continuation.resume()
            }
            player.delegate = delegate
            objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            player.play()
        }
    }
}
