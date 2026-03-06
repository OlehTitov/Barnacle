//
//  ScribeTranscriber.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

@preconcurrency import AVFoundation
import AVFoundation
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
    private var audioEngine = AVAudioEngine()
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
    private var eouTimeout: TimeInterval = 2.0
    private var lastCommitDate: Date?
    private var hasPartialText = false
    private var speechEndDate: Date?
    private var partialEouTimeout: TimeInterval = 1.5
    private var initialSilenceTimeout: TimeInterval = 5.0
    private var recordingStartDate: Date?
    private var isWebSocketReady = false
    private var isDrainingOutboundAudio = false
    private let outboundAudioLock = NSLock()
    private var outboundAudioChunks: [Data] = []
    private let maxBufferedAudioChunks = 48

    func prepareVad() async throws {
        guard vadManager == nil else { return }
        vadManager = try await VadManager(
            config: VadConfig(defaultThreshold: 0.75)
        )
    }

    func start(
        apiKey: String,
        eouTimeout: TimeInterval = 2.0,
        skipAudioSessionSetup: Bool = false,
        audioRoutingMode: AudioRoutingMode = .nativeCarBluetooth
    ) async throws {
        self.eouTimeout = eouTimeout
        self.partialEouTimeout = max(0.5, eouTimeout)
        self.initialSilenceTimeout = max(2.0, eouTimeout * 2)

        self.apiKey = apiKey

        if !skipAudioSessionSetup {
            try AudioUtilities.activateVoiceCaptureSession(routingMode: audioRoutingMode)
        }
        try AudioUtilities.applyPreferredInput(for: audioRoutingMode)

        if vadManager == nil {
            vadManager = try await VadManager(
                config: VadConfig(defaultThreshold: 0.75)
            )
        }

        // Reset engine to clear stale format cache
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        updateVoiceProcessing()
        audioEngine.prepare()

        // Use the node's actual format — don't fight internal format bridging
        let actualFormat = inputNode.outputFormat(forBus: 0)
        let tFormat = AudioUtilities.transcriptionFormat
        targetFormat = tFormat

        guard let converter = AVAudioConverter(
            from: actualFormat,
            to: tFormat
        ) else {
            onSystemLog?("Converter failed: \(actualFormat.sampleRate)Hz → \(tFormat.sampleRate)Hz")
            return
        }
        audioConverter = converter

        onSystemLog?("HW format: \(actualFormat.sampleRate)Hz, \(actualFormat.channelCount)ch")

        vadState = await vadManager!.makeStreamState()
        sampleBuffer.clear()
        resetOutboundAudio()
        connectWebSocket()

        let buffer = sampleBuffer
        var currentConverter = converter
        var currentFormat = actualFormat

        // Pass nil format — accept whatever the node delivers natively
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] pcm, _ in
            guard let self else { return }
            let level = AudioUtilities.audioLevel(from: pcm)
            Task { @MainActor [weak self] in self?.audioLevel = level }

            // Dynamic converter: recreate if buffer format changed (BT connect/disconnect)
            if !pcm.format.isEqual(currentFormat) {
                if let newConv = AVAudioConverter(from: pcm.format, to: tFormat) {
                    currentConverter = newConv
                    currentFormat = pcm.format
                    self.onSystemLog?("Converter: \(pcm.format.sampleRate)Hz → 16kHz")
                }
            }

            guard let samples = AudioUtilities.convertToMono16kHz(
                buffer: pcm,
                converter: currentConverter,
                targetFormat: tFormat
            ) else { return }

            buffer.append(samples)
            self.enqueueAudioForScribe(samples)
        }

        try audioEngine.start()

        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let ins = route.inputs.map { $0.portType.rawValue }.joined(separator: ", ")
        let outs = route.outputs.map { $0.portType.rawValue }.joined(separator: ", ")
        onSystemLog?("Post-engine route — in: [\(ins)] out: [\(outs)]")

        state = .recording
        audioLevel = 0
        silenceProgress = 0
        isSpeechActive = false
        hasCommittedText = false
        hasPartialText = false
        lastScribeActivityDate = nil
        lastCommitDate = nil
        speechEndDate = nil
        recordingStartDate = Date()
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
        audioEngine.stop()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        processingTask?.cancel()
        processingTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        lastScribeActivityDate = nil
        lastCommitDate = nil
        speechEndDate = nil
        recordingStartDate = nil
        resetOutboundAudio()
        state = .stopped
    }

    func updateVoiceProcessing() {
        guard !audioEngine.isRunning else {
            onSystemLog?("VP IO deferred while engine running")
            return
        }
        let shouldEnable = AudioUtilities.shouldEnableVoiceProcessing()
        do {
            try audioEngine.inputNode.setVoiceProcessingEnabled(shouldEnable)
            let route = AudioUtilities.currentOutputRoute()
            onSystemLog?("VP IO: \(shouldEnable ? "on" : "off") (route: \(route))")
        } catch {
            onSystemLog?("VP IO error: \(error.localizedDescription)")
        }
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
        hasPartialText = false
        lastScribeActivityDate = nil
        lastCommitDate = nil
        speechEndDate = nil
        resetOutboundAudio()
    }

    private func connectWebSocket() {
        guard webSocketTask == nil else { return }
        isWebSocketReady = false

        var components = URLComponents(
            string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
        )!
        components.queryItems = [
            URLQueryItem(name: "model_id", value: "scribe_v2_realtime"),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "vad"),
            URLQueryItem(
                name: "vad_silence_threshold_secs",
                value: String(format: "%.2f", eouTimeout)
            )
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        onSystemLog?("Scribe WS connected")
        onSystemLog?("Scribe provider VAD: \(String(format: "%.2f", eouTimeout))s")
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
                guard self.state == .recording else { return }
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
                self.onSystemLog?("Scribe session ready")
                self.handleWebSocketReady()
                break
            case "partial_transcript":
                if let partialText = json["text"] as? String {
                    self.currentPartial = partialText
                    self.displayText = self.committedText + partialText
                    self.hasPartialText = true
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
                    self.lastCommitDate = Date()
                }
            default:
                break
            }
        }
    }

    private nonisolated static func pcm16Data(from samples: [Float]) -> Data {
        let count = samples.count
        var int16Data = Data(count: count * 2)
        int16Data.withUnsafeMutableBytes { rawPtr in
            let ptr = rawPtr.bindMemory(to: Int16.self)
            for i in 0..<count {
                let sample = max(-1.0, min(1.0, samples[i]))
                ptr[i] = Int16(sample * Float(Int16.max))
            }
        }
        return int16Data
    }

    private nonisolated static func audioChunkMessage(from pcmData: Data) -> URLSessionWebSocketTask.Message {
        let base64 = pcmData.base64EncodedString()
        let json = "{\"message_type\":\"input_audio_chunk\",\"audio_base_64\":\"\(base64)\"}"
        return .string(json)
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
                    onSystemLog?("Scribe: speech detected")
                case .speechEnd:
                    isSpeechActive = false
                    speechEndDate = Date()
                    onSystemLog?("Scribe: speech ended")
                }
            }
        } catch {
            onSystemLog?("Scribe VAD error: \(error.localizedDescription)")
        }
    }

    private func startSilenceDetection() {
        lastScribeActivityDate = nil
        lastCommitDate = nil
        hasCommittedText = false
        hasPartialText = false
        speechEndDate = nil
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }

            guard !self.isSpeechActive else {
                self.silenceProgress = 0
                return
            }

            let now = Date()

            // Path 1: Committed text — 2s since last COMMIT (not partial)
            if self.hasCommittedText, let lastCommit = self.lastCommitDate {
                let elapsed = now.timeIntervalSince(lastCommit)
                if elapsed >= self.eouTimeout {
                    self.onSystemLog?("Scribe: EOU (committed)")
                    self.stop()
                    return
                }
                self.silenceProgress = min(1, elapsed / self.eouTimeout)
            }
            // Path 2: Partial-only — 1.5s since speech ended or last partial
            else if self.hasPartialText {
                let ref = max(
                    self.speechEndDate ?? .distantPast,
                    self.lastScribeActivityDate ?? .distantPast
                )
                guard ref != .distantPast else {
                    self.silenceProgress = 0
                    return
                }
                let elapsed = now.timeIntervalSince(ref)
                if elapsed >= self.partialEouTimeout {
                    self.onSystemLog?("Scribe: EOU (partial-only)")
                    self.stop()
                    return
                }
                self.silenceProgress = min(1, elapsed / self.partialEouTimeout)
            } else if let start = self.recordingStartDate {
                let elapsed = now.timeIntervalSince(start)
                if elapsed >= self.initialSilenceTimeout {
                    self.onSystemLog?("Scribe: EOU (no speech)")
                    self.stop()
                }
            } else {
                self.silenceProgress = 0
            }
        }
    }

    private func enqueueAudioForScribe(_ samples: [Float]) {
        let pcmData = Self.pcm16Data(from: samples)
        var shouldStartDrain = false
        outboundAudioLock.lock()
        outboundAudioChunks.append(pcmData)
        if !isWebSocketReady {
            if outboundAudioChunks.count > maxBufferedAudioChunks {
                outboundAudioChunks.removeFirst(outboundAudioChunks.count - maxBufferedAudioChunks)
            }
        } else if !isDrainingOutboundAudio {
            isDrainingOutboundAudio = true
            shouldStartDrain = true
        }
        outboundAudioLock.unlock()

        if shouldStartDrain {
            drainOutboundAudio()
        }
    }

    private func handleWebSocketReady() {
        var bufferedCount = 0
        var shouldStartDrain = false
        outboundAudioLock.lock()
        bufferedCount = outboundAudioChunks.count
        isWebSocketReady = true
        if !isDrainingOutboundAudio && !outboundAudioChunks.isEmpty {
            isDrainingOutboundAudio = true
            shouldStartDrain = true
        }
        outboundAudioLock.unlock()

        if bufferedCount > 0 {
            onSystemLog?("Scribe pre-roll queued: \(bufferedCount) chunks")
        }

        if shouldStartDrain {
            drainOutboundAudio()
        }
    }

    private func drainOutboundAudio() {
        guard let task = webSocketTask else {
            outboundAudioLock.lock()
            isDrainingOutboundAudio = false
            outboundAudioLock.unlock()
            return
        }

        Task { [weak self] in
            while true {
                guard let self else { return }

                let nextChunk: Data?
                self.outboundAudioLock.lock()
                if !self.isWebSocketReady || self.outboundAudioChunks.isEmpty {
                    self.isDrainingOutboundAudio = false
                    self.outboundAudioLock.unlock()
                    break
                }
                nextChunk = self.outboundAudioChunks.removeFirst()
                self.outboundAudioLock.unlock()

                if let nextChunk {
                    try? await task.send(Self.audioChunkMessage(from: nextChunk))
                }
            }
        }
    }

    private func resetOutboundAudio() {
        outboundAudioLock.lock()
        isWebSocketReady = false
        isDrainingOutboundAudio = false
        outboundAudioChunks.removeAll()
        outboundAudioLock.unlock()
    }
}
