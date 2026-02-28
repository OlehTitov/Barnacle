//
//  VoiceRecorder.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import AVFoundation
import Speech

@Observable
final class VoiceRecorder {

    private(set) var state: RecordingState = .idle

    private(set) var audioLevel: Float = 0

    private(set) var silenceProgress: Double = 0

    private(set) var audioFileURL: URL?

    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var silenceTimer: Timer?
    private var recordingTimer: Timer?
    private var currentPowerLevel: Float = -160
    private var silenceStartDate: Date?
    private var hasSpoken = false
    private var speechFrameCount = 0
    private let speechFrameThreshold = 3
    private let silenceThreshold: Float = -40
    private let silenceDuration: TimeInterval = 3.0
    private let maxRecordingDuration: TimeInterval = 60

    func startRecording(saveToFile: Bool = false, skipAudioSessionSetup: Bool = false) throws {
        if !skipAudioSessionSetup {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        if saveToFile {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")
            let file = try AVAudioFile(
                forWriting: fileURL,
                settings: recordingFormat.settings
            )
            self.audioFile = file
            self.audioFileURL = fileURL

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self else { return }
                try? file.write(from: buffer)
                self.processPowerLevel(buffer: buffer)
            }
        } else {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.recognitionRequest = request

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self else { return }
                request.append(buffer)
                self.processPowerLevel(buffer: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        state = .recording
        audioLevel = 0
        silenceProgress = 0
        hasSpoken = false
        speechFrameCount = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }

        startSilenceDetection()
    }

    func stopRecording() {
        guard state == .recording else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioFile = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        silenceStartDate = nil
        state = .stopped
    }

    func reset() {
        recognitionRequest = nil
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioFileURL = nil
        audioFile = nil
        state = .idle
        audioLevel = 0
        silenceProgress = 0
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
        let linear = max(0, min(1, (db + 50) / 50))
        let normalized = sqrt(linear)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentPowerLevel = db
            self.audioLevel = normalized
            if !self.hasSpoken {
                if db >= self.silenceThreshold {
                    self.speechFrameCount += 1
                    if self.speechFrameCount >= self.speechFrameThreshold {
                        self.hasSpoken = true
                    }
                } else {
                    self.speechFrameCount = 0
                }
            }
        }
    }

    private func startSilenceDetection() {
        silenceStartDate = nil
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            if self.currentPowerLevel >= self.silenceThreshold {
                self.silenceStartDate = nil
                self.silenceProgress = 0
            } else if self.hasSpoken {
                if self.silenceStartDate == nil {
                    self.silenceStartDate = Date()
                }
                if let start = self.silenceStartDate {
                    let elapsed = Date().timeIntervalSince(start)
                    self.silenceProgress = min(1, elapsed / self.silenceDuration)
                    if elapsed >= self.silenceDuration {
                        self.stopRecording()
                    }
                }
            }
        }
    }
}
