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
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        connectWebSocket(apiKey: apiKey)

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else { return }

        guard let audioConverter = AVAudioConverter(
            from: nativeFormat,
            to: targetFormat
        ) else { return }

        let ws = webSocketTask

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.processPowerLevel(buffer: buffer)
            Self.convertAndSend(
                buffer: buffer,
                converter: audioConverter,
                targetFormat: targetFormat,
                webSocketTask: ws
            )
        }

        audioEngine.prepare()
        try audioEngine.start()
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

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.receiveMessage()
            case .failure:
                break
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["message_type"] as? String
        else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch messageType {
            case "partial_transcript":
                if let partialText = json["text"] as? String {
                    self.currentPartial = partialText
                    self.displayText = self.committedText + partialText
                }
            case "committed_transcript":
                if let segment = json["text"] as? String {
                    self.committedText += (self.committedText.isEmpty ? "" : " ") + segment
                    self.currentPartial = ""
                    self.displayText = self.committedText
                }
            default:
                break
            }
        }
    }

    private nonisolated static func convertAndSend(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat,
        webSocketTask: URLSessionWebSocketTask?
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

        guard error == nil, convertedBuffer.frameLength > 0 else { return }
        guard let floatData = convertedBuffer.floatChannelData?[0] else { return }

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
        let json = "{\"type\":\"input_audio_chunk\",\"audio\":\"\(base64)\"}"

        Task {
            try? await webSocketTask?.send(.string(json))
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
