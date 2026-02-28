//
//  TTSPlayer.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import AVFoundation

@Observable
final class TTSPlayer {

    private(set) var isPlaying = false

    private var audioPlayer: AVAudioPlayer?

    func speak(
        _ text: String,
        apiKey: String,
        voiceID: String,
        modelID: String,
        stability: Double,
        similarityBoost: Double,
        style: Double
    ) async throws {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
            throw TTSError.invalidVoiceID
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
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

        audioPlayer = try AVAudioPlayer(data: data)
        isPlaying = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let delegate = PlayerDelegate {
                continuation.resume()
            }
            audioPlayer?.delegate = delegate
            objc_setAssociatedObject(audioPlayer!, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            audioPlayer?.play()
        }

        isPlaying = false
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
}

private class PlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {

    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
