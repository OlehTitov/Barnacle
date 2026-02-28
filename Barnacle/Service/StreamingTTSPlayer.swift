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

    private var scheduledChunkCount = 0

    private var completedChunkCount = 0

    private var meteringTimer: Timer?

    private var chunkContinuation: AsyncStream<String>.Continuation?

    private var processingTask: Task<Void, Never>?

    private var apiKey = ""

    private var voiceID = ""

    private var stability: Double = 0.5

    private var similarityBoost: Double = 0.8

    private var style: Double = 0.4

    private var currentPlayer: AVAudioPlayer?

    private var pendingPlayers: [AVAudioPlayer] = []

    private var modelID = "eleven_v3"

    func connect(
        apiKey: String,
        voiceID: String,
        modelID: String,
        stability: Double,
        similarityBoost: Double,
        style: Double
    ) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.modelID = modelID
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        chunkContinuation = continuation

        processingTask = Task { [weak self] in
            print("[TTS] Processing task started")
            for await chunk in stream {
                print("[TTS] Dequeued chunk: \(chunk.prefix(30))...")
                await self?.fetchAndScheduleAudio(for: chunk)
            }
            print("[TTS] Processing task done")
        }

        startMetering()
    }

    func sendTextChunk(_ text: String) {
        print("[TTS] sendTextChunk: \(text.prefix(40))...")
        chunkContinuation?.yield(text)
    }

    func endStream() {
        print("[TTS] endStream called")
        chunkContinuation?.finish()
        chunkContinuation = nil
    }

    func waitForPlaybackComplete() async {
        print("[TTS] waitForPlaybackComplete: waiting for processingTask...")
        await processingTask?.value
        print("[TTS] processingTask done. scheduled=\(scheduledChunkCount), completed=\(completedChunkCount)")

        let deadline = Date().addingTimeInterval(30)
        while completedChunkCount < scheduledChunkCount, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("[TTS] waitForPlaybackComplete finished. completed=\(completedChunkCount)/\(scheduledChunkCount)")
    }

    func disconnect() {
        print("[TTS] disconnect called")
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
            self.audioLevel = Self.normalizeDecibels(power)
        }
    }

    private static func normalizeDecibels(_ db: Float) -> Float {
        // Map -50 dB..0 dB to 0..1, apply sqrt for natural VU response
        let linear = max(0, min(1, (db + 50) / 50))
        return sqrt(linear)
    }

    private func fetchAndScheduleAudio(for text: String) async {
        print("[TTS] fetchAndScheduleAudio called for: \(text.prefix(30))...")
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream") else {
            print("[TTS] Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelID,
            "voice_settings": [
                "stability": stability,
                "similarity_boost": similarityBoost,
                "style": style
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("[TTS] JSON serialization failed")
            return
        }
        request.httpBody = httpBody

        do {
            print("[TTS] Sending HTTP request to ElevenLabs...")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[TTS] Not an HTTP response")
                return
            }

            print("[TTS] HTTP status: \(httpResponse.statusCode), data size: \(data.count) bytes")

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("[TTS] Error body: \(errorBody.prefix(200))")
                }
                return
            }

            scheduleAudioData(data)
        } catch {
            print("[TTS] HTTP error: \(error)")
            return
        }
    }

    private func scheduleAudioData(_ data: Data) {
        print("[TTS] scheduleAudioData called, data size: \(data.count) bytes")
        do {
            let player = try AVAudioPlayer(data: data)
            player.isMeteringEnabled = true
            scheduledChunkCount += 1
            print("[TTS] Created player #\(scheduledChunkCount)")

            if currentPlayer == nil {
                currentPlayer = player
                playChunk(player)
            } else {
                pendingPlayers.append(player)
            }
        } catch {
            print("[TTS] AVAudioPlayer error: \(error)")
        }
    }

    private func playChunk(_ player: AVAudioPlayer) {
        let delegate = ChunkPlayerDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.onChunkFinished()
            }
        }
        objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        player.delegate = delegate
        player.play()
        print("[TTS] Playing chunk \(completedChunkCount + 1)")
    }

    private func onChunkFinished() {
        completedChunkCount += 1
        print("[TTS] Chunk completed: \(completedChunkCount)/\(scheduledChunkCount)")

        if let next = pendingPlayers.first {
            pendingPlayers.removeFirst()
            currentPlayer = next
            playChunk(next)
        } else {
            currentPlayer = nil
        }
    }
}

private class ChunkPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {

    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
