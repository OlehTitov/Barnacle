//
//  ScribeTranscriber.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

@preconcurrency import AVFoundation
import FluidAudio
import Foundation

@Observable
final class ScribeTranscriber {

    private(set) var displayText: String = ""

    private(set) var audioLevel: Float = 0

    private(set) var silenceProgress: Double = 0

    private(set) var state: RecordingState = .idle

    var onSystemLog: ((String) -> Void)?

    var finalTranscript: String {
        let combined = committedText + currentPartial
        return combined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var committedText = ""
    private var currentPartial = ""
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var recordingTimer: Timer?
    private var apiKey = ""
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private let maxRecordingDuration: TimeInterval = 60

    private var vadManager: VadManager?
    private var vadState: VadStreamState?
    private var isSpeechActive = false
    private let sampleBuffer = AudioSampleBuffer()
    private var processingTask: Task<Void, Never>?
    private var lastScribeActivityDate: Date?
    private var hasCommittedText = false
    private let eouTimeout: TimeInterval = 2.0

    func prepareVad() async throws {
        guard vadManager == nil else { return }
        vadManager = try await VadManager(
            config: VadConfig(defaultThreshold: 0.75)
        )
    }

    func start(apiKey: String, skipAudioSessionSetup: Bool = false) async throws {
        self.apiKey = apiKey

        if !skipAudioSessionSetup {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }

        if vadManager == nil {
            vadManager = try await VadManager(
                config: VadConfig(defaultThreshold: 0.75)
            )
        }

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        let tFormat = AudioUtilities.transcriptionFormat
        targetFormat = tFormat

        guard let converter = AVAudioConverter(
            from: nativeFormat,
            to: tFormat
        ) else {
            onSystemLog?("Scribe: converter failed")
            return
        }
        audioConverter = converter

        vadState = await vadManager!.makeStreamState()
        sampleBuffer.clear()

        var chunkCount = 0
        let buffer = sampleBuffer

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] pcm, _ in
            guard let self else { return }
            let level = AudioUtilities.audioLevel(from: pcm)
            Task { @MainActor [weak self] in self?.audioLevel = level }
            chunkCount += 1

            guard let samples = AudioUtilities.convertToMono16kHz(
                buffer: pcm,
                converter: converter,
                targetFormat: tFormat
            ) else { return }

            buffer.append(samples)

            guard self.webSocketTask != nil else { return }
            Self.sendSamples(
                samples,
                webSocketTask: self.webSocketTask,
                chunkIndex: chunkCount
            )
        }

        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
        }
        onSystemLog?("Scribe engine ready")
        state = .recording
        audioLevel = 0
        silenceProgress = 0
        isSpeechActive = false
        hasCommittedText = false
        lastScribeActivityDate = nil
        displayText = ""
        committedText = ""
        currentPartial = ""

        processingTask = Task { [weak self] in
            await self?.processAudioLoop()
        }

        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: maxRecordingDuration,
            repeats: false
        ) { [weak self] _ in
            self?.stop()
        }

        startSilenceDetection()
    }

    func stop() {
        guard state == .recording else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        processingTask?.cancel()
        processingTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        lastScribeActivityDate = nil
        state = .stopped
    }

    func stopEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    func reset() {
        displayText = ""
        committedText = ""
        currentPartial = ""
        state = .idle
        audioLevel = 0
        silenceProgress = 0
        isSpeechActive = false
        hasCommittedText = false
        lastScribeActivityDate = nil
    }

    private func connectWebSocket() {
        guard webSocketTask == nil else { return }

        var components = URLComponents(
            string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
        )!
        components.queryItems = [
            URLQueryItem(name: "model_id", value: "scribe_v2_realtime"),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "vad"),
            URLQueryItem(name: "vad_silence_threshold_secs", value: "1.5")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        onSystemLog?("Scribe WS connected")
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data:
                    break
                @unknown default:
                    break
                }
                self.receiveMessage()
            case .failure(let error):
                self.onSystemLog?("Scribe WS error: \(error.localizedDescription)")
                break
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let messageType = json["message_type"] as? String else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch messageType {
            case "session_started":
                break
            case "partial_transcript":
                if let partialText = json["text"] as? String {
                    self.currentPartial = partialText
                    self.displayText = self.committedText + partialText
                    self.lastScribeActivityDate = Date()
                }
            case "committed_transcript":
                if let segment = json["text"] as? String {
                    let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        self.committedText += (self.committedText.isEmpty ? "" : " ") + segment
                        self.displayText = self.committedText
                        self.hasCommittedText = true
                        let preview = String(trimmed.prefix(40))
                        self.onSystemLog?("Scribe committed: \(preview)")
                    }
                    self.currentPartial = ""
                    self.lastScribeActivityDate = Date()
                }
            default:
                break
            }
        }
    }

    private nonisolated static func sendSamples(
        _ samples: [Float],
        webSocketTask: URLSessionWebSocketTask?,
        chunkIndex: Int = 0
    ) {
        let count = samples.count
        var int16Data = Data(count: count * 2)
        int16Data.withUnsafeMutableBytes { rawPtr in
            let ptr = rawPtr.bindMemory(to: Int16.self)
            for i in 0..<count {
                let sample = max(-1.0, min(1.0, samples[i]))
                ptr[i] = Int16(sample * Float(Int16.max))
            }
        }

        let base64 = int16Data.base64EncodedString()
        let json = "{\"message_type\":\"input_audio_chunk\",\"audio_base_64\":\"\(base64)\"}"

        Task {
            try? await webSocketTask?.send(.string(json))
        }
    }

    private func processAudioLoop() async {
        let chunkSize = VadManager.chunkSize

        while state == .recording {
            let chunk = sampleBuffer.drain(size: chunkSize)

            guard let chunk else {
                try? await Task.sleep(for: .milliseconds(10))
                continue
            }

            await processVadChunk(chunk)
        }
    }

    private func processVadChunk(_ chunk: [Float]) async {
        guard let vadManager, let currentState = vadState else { return }

        do {
            let result = try await vadManager.processStreamingChunk(
                chunk,
                state: currentState,
                config: .default,
                returnSeconds: true,
                timeResolution: 2
            )
            vadState = result.state

            if let event = result.event {
                switch event.kind {
                case .speechStart:
                    isSpeechActive = true
                    connectWebSocket()
                    onSystemLog?("Scribe: speech detected")
                case .speechEnd:
                    isSpeechActive = false
                    onSystemLog?("Scribe: speech ended")
                }
            }
        } catch {
            onSystemLog?("Scribe VAD error: \(error.localizedDescription)")
        }
    }

    private func startSilenceDetection() {
        lastScribeActivityDate = nil
        hasCommittedText = false
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }

            guard self.hasCommittedText, !self.isSpeechActive else {
                self.silenceProgress = 0
                return
            }

            guard let lastActivity = self.lastScribeActivityDate else {
                self.silenceProgress = 0
                return
            }

            let elapsed = Date().timeIntervalSince(lastActivity)
            self.silenceProgress = min(1, elapsed / self.eouTimeout)

            if elapsed >= self.eouTimeout {
                self.onSystemLog?("Scribe: EOU timeout")
                self.stop()
            }
        }
    }
}
