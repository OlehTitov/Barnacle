//
//  ScribeTranscriber.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

@preconcurrency import AVFoundation
import Foundation

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
    private var currentPowerLevel: Float = -160
    private var silenceStartDate: Date?
    private let silenceThreshold: Float = -40
    private let silenceDuration: TimeInterval = 3.0
    private let maxRecordingDuration: TimeInterval = 60

    func start(apiKey: String) throws {
        print("[Scribe] start() called, apiKey length=\(apiKey.count)")

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        connectWebSocket(apiKey: apiKey)

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        print("[Scribe] nativeFormat: sampleRate=\(nativeFormat.sampleRate), channels=\(nativeFormat.channelCount)")

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            print("[Scribe] ERROR: failed to create targetFormat")
            return
        }

        guard let audioConverter = AVAudioConverter(
            from: nativeFormat,
            to: targetFormat
        ) else {
            print("[Scribe] ERROR: failed to create AVAudioConverter")
            return
        }
        print("[Scribe] converter created: \(nativeFormat.sampleRate)Hz \(nativeFormat.channelCount)ch -> 16000Hz 1ch")

        let ws = webSocketTask
        print("[Scribe] webSocketTask captured: \(ws != nil)")
        var chunkCount = 0

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.processPowerLevel(buffer: buffer)
            chunkCount += 1
            if chunkCount <= 3 || chunkCount % 50 == 0 {
                print("[Scribe] tap #\(chunkCount): bufferFrames=\(buffer.frameLength)")
            }
            Self.convertAndSend(
                buffer: buffer,
                converter: audioConverter,
                targetFormat: targetFormat,
                webSocketTask: ws,
                chunkIndex: chunkCount
            )
        }

        audioEngine.prepare()
        try audioEngine.start()
        print("[Scribe] audioEngine started")
        state = .recording
        audioLevel = 0
        silenceProgress = 0
        displayText = ""
        committedText = ""
        currentPartial = ""

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
        audioEngine.stop()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        silenceStartDate = nil
        state = .stopped
        print("[Scribe] stopped, finalTranscript=\"\(finalTranscript)\"")
    }

    func reset() {
        displayText = ""
        committedText = ""
        currentPartial = ""
        state = .idle
        audioLevel = 0
        silenceProgress = 0
    }

    private func connectWebSocket(apiKey: String) {
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
        print("[Scribe] WebSocket resumed")
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
                }
            case "committed_transcript":
                if let segment = json["text"] as? String {
                    print("[Scribe] committed: \"\(segment)\"")
                    self.committedText += (self.committedText.isEmpty ? "" : " ") + segment
                    self.currentPartial = ""
                    self.displayText = self.committedText
                }
            default:
                print("[Scribe] unhandled message_type: \(messageType), json=\(json)")
                break
            }
        }
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

    private nonisolated func processPowerLevel(buffer: AVAudioPCMBuffer) {
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
            self?.currentPowerLevel = db
            self?.audioLevel = normalized
        }
    }

    private func startSilenceDetection() {
        silenceStartDate = nil
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            if self.currentPowerLevel < self.silenceThreshold {
                if self.silenceStartDate == nil {
                    self.silenceStartDate = Date()
                }
                if let start = self.silenceStartDate {
                    let elapsed = Date().timeIntervalSince(start)
                    self.silenceProgress = min(1, elapsed / self.silenceDuration)
                    if elapsed >= self.silenceDuration {
                        self.stop()
                    }
                }
            } else {
                self.silenceStartDate = nil
                self.silenceProgress = 0
            }
        }
    }
}
