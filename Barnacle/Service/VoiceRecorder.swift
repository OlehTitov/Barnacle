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
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var recordingTimer: Timer?
    private var currentPowerLevel: Float = -160
    private let silenceThreshold: Float = -40
    private let silenceDuration: TimeInterval = 1.5
    private let maxRecordingDuration: TimeInterval = 60

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            request.append(buffer)
            self.processPowerLevel(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        state = .recording

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
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        state = .stopped
    }

    func reset() {
        recognitionRequest = nil
        state = .idle
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

        Task { @MainActor [weak self] in
            self?.currentPowerLevel = db
        }
    }

    private func startSilenceDetection() {
        var silentSince: Date?
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            if self.currentPowerLevel < self.silenceThreshold {
                if silentSince == nil {
                    silentSince = Date()
                } else if let start = silentSince, Date().timeIntervalSince(start) >= self.silenceDuration {
                    self.stopRecording()
                }
            } else {
                silentSince = nil
            }
        }
    }
}
