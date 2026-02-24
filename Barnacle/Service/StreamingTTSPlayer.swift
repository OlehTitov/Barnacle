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

    private var audioEngine: AVAudioEngine?

    private var playerNode: AVAudioPlayerNode?

    private var engineFormat: AVAudioFormat?

    private var scheduledBufferCount = 0

    private var completedBufferCount = 0

    private var chunkContinuation: AsyncStream<String>.Continuation?

    private var processingTask: Task<Void, Never>?

    private var apiKey = ""

    private var voiceID = ""

    private var stability: Double = 0.5

    private var similarityBoost: Double = 0.8

    private var style: Double = 0.4

    func connect(
        apiKey: String,
        voiceID: String,
        stability: Double,
        similarityBoost: Double,
        style: Double
    ) {
        self.apiKey = apiKey
        self.voiceID = voiceID
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
        print("[TTS] processingTask done. scheduled=\(scheduledBufferCount), completed=\(completedBufferCount)")

        let deadline = Date().addingTimeInterval(30)
        while completedBufferCount < scheduledBufferCount, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("[TTS] waitForPlaybackComplete finished. completed=\(completedBufferCount)/\(scheduledBufferCount)")
    }

    func disconnect() {
        print("[TTS] disconnect called")
        chunkContinuation?.finish()
        chunkContinuation = nil
        processingTask?.cancel()
        processingTask = nil

        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
        engineFormat = nil

        scheduledBufferCount = 0
        completedBufferCount = 0
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
            "model_id": "eleven_v3",
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

    private func setupAudioEngine(format: AVAudioFormat) {
        print("[TTS] Setting up audio engine with format: \(format)")
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try engine.start()
            player.play()
            print("[TTS] Audio engine started successfully")
        } catch {
            print("[TTS] Audio engine setup failed: \(error)")
            return
        }

        audioEngine = engine
        playerNode = player
        engineFormat = format
    }

    private func scheduleAudioData(_ data: Data) {
        print("[TTS] scheduleAudioData called, data size: \(data.count) bytes")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")

        do {
            try data.write(to: tempURL)
            let audioFile = try AVAudioFile(forReading: tempURL)
            print("[TTS] Audio file: format=\(audioFile.processingFormat), length=\(audioFile.length)")

            if audioEngine == nil {
                setupAudioEngine(format: audioFile.processingFormat)
            }

            guard let playerNode else {
                print("[TTS] playerNode is nil after setup")
                try? FileManager.default.removeItem(at: tempURL)
                return
            }

            let targetFormat = engineFormat ?? audioFile.processingFormat
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            ) else {
                print("[TTS] Failed to create PCM buffer")
                try? FileManager.default.removeItem(at: tempURL)
                return
            }
            try audioFile.read(into: pcmBuffer)
            try? FileManager.default.removeItem(at: tempURL)

            scheduledBufferCount += 1
            print("[TTS] Scheduling buffer #\(scheduledBufferCount), frames: \(pcmBuffer.frameLength)")
            playerNode.scheduleBuffer(pcmBuffer) { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.completedBufferCount += 1
                    print("[TTS] Buffer completed: \(self.completedBufferCount)/\(self.scheduledBufferCount)")
                }
            }
        } catch {
            print("[TTS] scheduleAudioData error: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
