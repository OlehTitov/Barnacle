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
        config: TTSConfig
    ) async throws {
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
                "text": text,
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
                "input": text,
                "voice": config.openAIVoice,
                "response_format": "mp3"
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

        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.isMeteringEnabled = true
        isPlaying = true
        startMetering()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playbackContinuation = continuation
            let delegate = AudioPlayerFinishDelegate { [weak self] in
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
            self.audioLevel = AudioUtilities.normalizeDecibels(power)
        }
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        audioLevel = 0
    }
}
