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

    static func ensureCached(
        apiKey: String,
        voiceID: String,
        modelID: String,
        stability: Double,
        similarityBoost: Double,
        style: Double
    ) async throws {
        guard !isCached else { return }

        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
            throw TTSError.invalidVoiceID
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": "Boom, I'm here",
            "model_id": modelID,
            "voice_settings": [
                "stability": stability,
                "similarity_boost": similarityBoost,
                "style": style
            ]
        ])

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
            let delegate = GreetingPlayerDelegate {
                continuation.resume()
            }
            player.delegate = delegate
            objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            player.play()
        }
    }
}

private class GreetingPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {

    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
