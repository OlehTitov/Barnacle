//
//  StreamingTTSPlayer.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import AVFoundation
import Foundation

@Observable
final class StreamingTTSPlayer {

    private(set) var audioLevel: Float = 0

    var onSystemLog: ((String) -> Void)?

    private var scheduledChunkCount = 0

    private var completedChunkCount = 0

    private var meteringTimer: Timer?

    private var chunkContinuation: AsyncStream<String>.Continuation?

    private var processingTask: Task<Void, Never>?

    private var config: TTSConfig?

    private var currentPlayer: AVAudioPlayer?

    private var pendingPlayers: [AVAudioPlayer] = []

    func connect(config: TTSConfig) {
        self.config = config

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        chunkContinuation = continuation

        processingTask = Task { [weak self] in
            for await chunk in stream {
                await self?.fetchAndScheduleAudio(for: chunk)
            }
        }

        onSystemLog?("TTS connected")
        startMetering()
    }

    func sendTextChunk(_ text: String) {
        chunkContinuation?.yield(text)
    }

    func endStream() {
        chunkContinuation?.finish()
        chunkContinuation = nil
    }

    func waitForPlaybackComplete() async {
        await processingTask?.value

        let deadline = Date().addingTimeInterval(30)
        while completedChunkCount < scheduledChunkCount, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        onSystemLog?("TTS done \(completedChunkCount)/\(scheduledChunkCount)")
    }

    func disconnect() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        audioLevel = 0

        chunkContinuation?.finish()
        chunkContinuation = nil
        processingTask?.cancel()
        processingTask = nil

        currentPlayer?.stop()
        currentPlayer = nil
        pendingPlayers.removeAll()

        scheduledChunkCount = 0
        completedChunkCount = 0
    }

    private func startMetering() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.currentPlayer, player.isPlaying else {
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

    private func fetchAndScheduleAudio(for text: String) async {
        guard let config else { return }

        let request: URLRequest

        switch config.provider {
        case .elevenLabs:
            guard let built = buildElevenLabsRequest(text: text, config: config) else { return }
            request = built
        case .openAI:
            guard let built = buildOpenAIRequest(text: text, config: config) else { return }
            request = built
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return }

            guard (200...299).contains(httpResponse.statusCode) else {
                onSystemLog?("TTS HTTP \(httpResponse.statusCode)")
                return
            }

            scheduleAudioData(data)
        } catch {
            onSystemLog?("TTS error: \(error.localizedDescription)")
            return
        }
    }

    private func buildElevenLabsRequest(text: String, config: TTSConfig) -> URLRequest? {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(config.voiceID)/stream") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")

        var voiceSettings: [String: Any] = [
            "stability": config.stability,
            "similarity_boost": config.similarityBoost,
            "style": config.style
        ]
        if config.modelID != TTSModel.v3.rawValue {
            voiceSettings["speed"] = config.elevenLabsSpeed
        }
        let body: [String: Any] = [
            "text": text,
            "model_id": config.modelID,
            "voice_settings": voiceSettings
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody
        return request
    }

    private func buildOpenAIRequest(text: String, config: TTSConfig) -> URLRequest? {
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.openAIAPIKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": "gpt-4o-mini-tts",
            "input": text,
            "voice": config.openAIVoice,
            "response_format": "mp3",
            "speed": config.openAISpeed
        ]

        if !config.openAIVoiceInstructions.isEmpty {
            body["instructions"] = config.openAIVoiceInstructions
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody
        return request
    }

    private func scheduleAudioData(_ data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.isMeteringEnabled = true
            scheduledChunkCount += 1
            onSystemLog?("TTS playing chunk \(scheduledChunkCount)")

            if currentPlayer == nil {
                currentPlayer = player
                playChunk(player)
            } else {
                pendingPlayers.append(player)
            }
        } catch {
            onSystemLog?("TTS player error: \(error.localizedDescription)")
        }
    }

    private func playChunk(_ player: AVAudioPlayer) {
        let delegate = AudioPlayerFinishDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.onChunkFinished()
            }
        }
        objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        player.delegate = delegate
        player.play()
    }

    private func onChunkFinished() {
        completedChunkCount += 1

        if let next = pendingPlayers.first {
            pendingPlayers.removeFirst()
            currentPlayer = next
            playChunk(next)
        } else {
            currentPlayer = nil
        }
    }
}
