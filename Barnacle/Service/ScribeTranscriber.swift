//
//  ScribeTranscriber.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

@preconcurrency import AVFoundation
import FluidAudio
import Foundation

private final class AudioSampleBuffer: @unchecked Sendable {

    private let lock = NSLock()

    nonisolated(unsafe) private var samples: [Float] = []

    nonisolated func append(_ newSamples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        samples.append(contentsOf: newSamples)
    }

    nonisolated func drain(size: Int) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        guard samples.count >= size else { return nil }
        let chunk = Array(samples.prefix(size))
        samples.removeFirst(size)
        return chunk
    }

    nonisolated func clear() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll()
    }
}

@Observable
final class ScribeTranscriber {

    private(set) var displayText: String = ""

    private(set) var audioLevel: Float = 0

    private(set) var silenceProgress: Double = 0

    private(set) var state: RecordingState = .idle

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

    func start(apiKey: String, skipAudioSessionSetup: Bool = false) async throws {
        print("[Scribe] start() called, apiKey length=\(apiKey.count)")
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
        print("[Scribe] nativeFormat: sampleRate=\(nativeFormat.sampleRate), channels=\(nativeFormat.channelCount)")

        guard let tFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            print("[Scribe] ERROR: failed to create targetFormat")
            return
        }
        targetFormat = tFormat

        guard let converter = AVAudioConverter(
            from: nativeFormat,
            to: tFormat
        ) else {
            print("[Scribe] ERROR: failed to create AVAudioConverter")
            return
        }
        audioConverter = converter
        print("[Scribe] converter created: \(nativeFormat.sampleRate)Hz \(nativeFormat.channelCount)ch -> 16000Hz 1ch")

        vadState = await vadManager!.makeStreamState()
        sampleBuffer.clear()

        var chunkCount = 0
        let buffer = sampleBuffer

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] pcm, _ in
            guard let self else { return }
            self.updateAudioLevel(buffer: pcm)
            chunkCount += 1

            Self.convertAndAccumulate(
                buffer: pcm,
                converter: converter,
                targetFormat: tFormat,
                sampleBuffer: buffer
            )

            guard self.webSocketTask != nil else { return }
            if chunkCount <= 3 || chunkCount % 50 == 0 {
                print("[Scribe] tap #\(chunkCount): bufferFrames=\(pcm.frameLength)")
            }
            Self.convertAndSend(
                buffer: pcm,
                converter: converter,
                targetFormat: tFormat,
                webSocketTask: self.webSocketTask,
                chunkIndex: chunkCount
            )
        }

        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
        }
        print("[Scribe] audioEngine started")
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
        print("[Scribe] stop() called, committed=\"\(committedText)\", partial=\"\(currentPartial)\"")
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
        print("[Scribe] stopped, finalTranscript=\"\(finalTranscript)\"")
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
        print("[Scribe] WebSocket URL: \(components.url!)")

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        print("[Scribe] WebSocket resumed (speech detected)")
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else {
                print("[Scribe] receiveMessage: self is nil")
                return
            }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("[Scribe] WS received string (\(text.prefix(200)))")
                    self.handleMessage(text)
                case .data(let data):
                    print("[Scribe] WS received binary data (\(data.count) bytes)")
                @unknown default:
                    print("[Scribe] WS received unknown message type")
                }
                self.receiveMessage()
            case .failure(let error):
                print("[Scribe] WS receive FAILED: \(error)")
                break
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("[Scribe] handleMessage: failed to convert text to data")
            return
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[Scribe] handleMessage: failed to parse JSON")
            return
        }
        guard let messageType = json["message_type"] as? String else {
            print("[Scribe] handleMessage: no message_type, keys=\(json.keys.sorted())")
            return
        }

        print("[Scribe] message_type=\(messageType)")

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch messageType {
            case "session_started":
                print("[Scribe] session started, config=\(json["config"] ?? "nil")")
            case "partial_transcript":
                if let partialText = json["text"] as? String {
                    print("[Scribe] partial: \"\(partialText)\"")
                    self.currentPartial = partialText
                    self.displayText = self.committedText + partialText
                    self.lastScribeActivityDate = Date()
                }
            case "committed_transcript":
                if let segment = json["text"] as? String {
                    print("[Scribe] committed: \"\(segment)\"")
                    self.committedText += (self.committedText.isEmpty ? "" : " ") + segment
                    self.currentPartial = ""
                    self.displayText = self.committedText
                    self.lastScribeActivityDate = Date()
                    self.hasCommittedText = true
                }
            default:
                print("[Scribe] unhandled message_type: \(messageType), json=\(json)")
                break
            }
        }
    }

    private nonisolated func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(max(frames, 1)))
        let db = 20 * log10(max(rms, 1e-10))
        let normalized = max(0, min(1, (db + 60) / 60))

        Task { @MainActor [weak self] in
            self?.audioLevel = normalized
        }
    }

    private nonisolated static func convertAndAccumulate(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat,
        sampleBuffer: AudioSampleBuffer
    ) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else { return }

        var inputProvided = false
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputProvided {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputProvided = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, convertedBuffer.frameLength > 0,
              let floatData = convertedBuffer.floatChannelData?[0]
        else { return }

        let count = Int(convertedBuffer.frameLength)
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = floatData[i]
        }

        sampleBuffer.append(samples)
    }

    private nonisolated static func convertAndSend(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat,
        webSocketTask: URLSessionWebSocketTask?,
        chunkIndex: Int = 0
    ) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else {
            print("[Scribe] convertAndSend: failed to create convertedBuffer")
            return
        }

        var inputProvided = false
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputProvided {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputProvided = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            print("[Scribe] convertAndSend: converter error: \(error)")
            return
        }
        guard convertedBuffer.frameLength > 0 else {
            if chunkIndex <= 3 {
                print("[Scribe] convertAndSend: 0 frames after conversion")
            }
            return
        }
        guard let floatData = convertedBuffer.floatChannelData?[0] else {
            print("[Scribe] convertAndSend: no float channel data")
            return
        }

        let count = Int(convertedBuffer.frameLength)
        var int16Data = Data(count: count * 2)
        int16Data.withUnsafeMutableBytes { rawPtr in
            let ptr = rawPtr.bindMemory(to: Int16.self)
            for i in 0..<count {
                let sample = max(-1.0, min(1.0, floatData[i]))
                ptr[i] = Int16(sample * Float(Int16.max))
            }
        }

        let base64 = int16Data.base64EncodedString()
        let json = "{\"message_type\":\"input_audio_chunk\",\"audio_base_64\":\"\(base64)\"}"

        if chunkIndex <= 3 || chunkIndex % 50 == 0 {
            print("[Scribe] sending chunk #\(chunkIndex): \(count) samples, \(int16Data.count) bytes, base64 len=\(base64.count)")
        }

        Task {
            do {
                try await webSocketTask?.send(.string(json))
            } catch {
                print("[Scribe] WS send FAILED chunk #\(chunkIndex): \(error)")
            }
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
                    print("[Scribe] VAD speechStart -> connecting WebSocket")
                case .speechEnd:
                    isSpeechActive = false
                    print("[Scribe] VAD speechEnd")
                }
            }
        } catch {
            print("[Scribe] VAD error: \(error)")
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
                print("[Scribe] EOU timeout reached (\(self.eouTimeout)s since last Scribe activity)")
                self.stop()
            }
        }
    }
}
