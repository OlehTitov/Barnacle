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

    private(set) var audioLevel: Float = 0

    private var audioPlayer: AVAudioPlayer?

    private var meteringTimer: Timer?

    private var playbackContinuation: CheckedContinuation<Void, Never>?

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
        audioPlayer?.isMeteringEnabled = true
        isPlaying = true
        startMetering()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playbackContinuation = continuation
            let delegate = PlayerDelegate { [weak self] in
                self?.playbackContinuation = nil
                continuation.resume()
            }
            audioPlayer?.delegate = delegate
            objc_setAssociatedObject(audioPlayer!, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            audioPlayer?.play()
        }

        stopMetering()
        isPlaying = false
    }

    func stop() {
        stopMetering()
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    private func startMetering() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer, player.isPlaying else {
                self?.audioLevel = 0
                return
            }
            player.updateMeters()
            let power = player.averagePower(forChannel: 0)
            guard power.isFinite, power < 0 else {
                self.audioLevel = 0
                return
            }
            self.audioLevel = Self.normalizeDecibels(power)
        }
    }

    private static func normalizeDecibels(_ db: Float) -> Float {
        let linear = max(0, min(1, (db + 50) / 50))
        return sqrt(linear)
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        audioLevel = 0
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
