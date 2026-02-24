//
//  ConversationService.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

@preconcurrency import AVFoundation
import Foundation
import Speech

@Observable
final class ConversationService {

    private(set) var phase: ConversationPhase = .idle

    private(set) var messages: [MessageModel] = []

    private(set) var liveTranscript: String = ""

    private(set) var audioLevel: Float = 0

    private(set) var silenceProgress: Double = 0

    private var recorder = VoiceRecorder()

    private var transcriber = Transcriber()

    private var ttsPlayer = TTSPlayer()

    private var streamingTTS = StreamingTTSPlayer()

    private var scribeTranscriber = ScribeTranscriber()

    func runTurn(config: AppConfig, playGreeting: Bool = false) async {
        do {
            try await activateAudioSession()

            if playGreeting && GreetingCacheService.isCached {
                phase = .greeting
                try await GreetingCacheService.playGreeting()
            }

            let finalText = try await listen(config: config)

            guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                resetRecorders()
                phase = .idle
                return
            }

            try await sendToOpenClaw(finalText, config: config)
            phase = .finished
        } catch {
            phase = .failed(error.localizedDescription)
        }

        resetRecorders()
    }

    func stopListening() {
        if scribeTranscriber.state == .recording {
            scribeTranscriber.stop()
        } else if recorder.state == .recording {
            recorder.stopRecording()
        }
    }

    private func listen(config: AppConfig) async throws -> String {
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                throw IntentError.microphonePermissionDenied
            }
        } else if micStatus == .denied {
            throw IntentError.microphonePermissionDenied
        }

        phase = .listening

        switch config.transcriptionEngine {
        case .apple:
            return try await listenApple()
        case .scribe:
            return try await listenScribe(config: config)
        case .whisper:
            return try await listenWhisper(config: config)
        }
    }

    private func listenApple() async throws -> String {
        let speechStatus = await Transcriber.requestAuthorization()
        guard speechStatus == .authorized else {
            throw TranscriberError.permissionDenied
        }

        transcriber.cancel()
        try recorder.startRecording(skipAudioSessionSetup: true)

        startLiveUpdates(engine: .apple)

        guard let request = recorder.recognitionRequest else {
            return ""
        }

        let finalText = try await transcriber.transcribe(request: request)
        transcriber.cancel()
        return finalText
    }

    private func listenScribe(config: AppConfig) async throws -> String {
        try scribeTranscriber.start(
            apiKey: config.elevenLabsAPIKey,
            skipAudioSessionSetup: true
        )

        startLiveUpdates(engine: .scribe)

        while scribeTranscriber.state == .recording {
            try await Task.sleep(for: .milliseconds(100))
        }

        return scribeTranscriber.finalTranscript
    }

    private func listenWhisper(config: AppConfig) async throws -> String {
        try recorder.startRecording(saveToFile: true, skipAudioSessionSetup: true)

        startLiveUpdates(engine: .whisper)

        while recorder.state == .recording {
            try await Task.sleep(for: .milliseconds(100))
        }

        guard let fileURL = recorder.audioFileURL else {
            return ""
        }

        phase = .processing

        return try await WhisperService.transcribe(
            fileURL: fileURL,
            apiKey: config.openAIAPIKey,
            model: config.whisperModel
        )
    }

    private var isListening: Bool {
        if case .listening = phase { return true }
        return false
    }

    private func startLiveUpdates(engine: TranscriptionEngine) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            while self.isListening {
                switch engine {
                case .scribe:
                    self.liveTranscript = self.scribeTranscriber.displayText
                    self.audioLevel = self.scribeTranscriber.audioLevel
                    self.silenceProgress = self.scribeTranscriber.silenceProgress
                case .apple, .whisper:
                    self.liveTranscript = self.transcriber.partialResult
                    self.audioLevel = self.recorder.audioLevel
                    self.silenceProgress = self.recorder.silenceProgress
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func sendToOpenClaw(_ finalText: String, config: AppConfig) async throws {
        messages.append(MessageModel(role: .user, text: finalText))
        phase = .processing

        let hasTTS = !config.elevenLabsAPIKey.isEmpty && !config.voiceID.isEmpty
        var streamedText = ""
        var ttsConnected = false
        var streamingRequestFailed = false

        messages.append(MessageModel(role: .assistant, text: ""))
        let messageIndex = messages.count - 1

        do {
            let stream = try await OpenClawService.streamMessage(
                finalText,
                gatewayURL: config.gatewayURL,
                token: config.gatewayToken,
                hasTTS: hasTTS
            )

            var chunkBuffer = TextChunkBuffer()

            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    streamedText += delta
                    messages[messageIndex].text = streamedText

                    if hasTTS && !ttsConnected {
                        ttsConnected = true
                        streamingTTS.connect(
                            apiKey: config.elevenLabsAPIKey,
                            voiceID: config.voiceID,
                            stability: config.ttsStability.rawValue,
                            similarityBoost: config.ttsSimilarityBoost,
                            style: config.ttsStyle
                        )
                    }

                    if ttsConnected {
                        for chunk in chunkBuffer.add(delta) {
                            streamingTTS.sendTextChunk(chunk)
                        }
                    }

                case .textDone(let fullText):
                    streamedText = fullText
                    messages[messageIndex].text = fullText

                case .done:
                    break
                }
            }

            if ttsConnected {
                if let remainder = chunkBuffer.flush() {
                    streamingTTS.sendTextChunk(remainder)
                }
                streamingTTS.endStream()
                phase = .speaking
                await streamingTTS.waitForPlaybackComplete()
                streamingTTS.disconnect()
            }

        } catch {
            streamingRequestFailed = true
            streamingTTS.disconnect()
            ttsConnected = false
        }

        if streamingRequestFailed && streamedText.isEmpty {
            phase = .processing
            let response = try await OpenClawService.sendMessage(
                finalText,
                gatewayURL: config.gatewayURL,
                token: config.gatewayToken,
                hasTTS: hasTTS
            )
            streamedText = response
            messages[messageIndex].text = response
        } else if streamedText.isEmpty {
            messages[messageIndex].text = "No response"
        }

        if hasTTS && !ttsConnected && !streamedText.isEmpty {
            phase = .speaking
            try await ttsPlayer.speak(
                streamedText,
                apiKey: config.elevenLabsAPIKey,
                voiceID: config.voiceID,
                stability: config.ttsStability.rawValue,
                similarityBoost: config.ttsSimilarityBoost,
                style: config.ttsStyle
            )
        }
    }

    private func activateAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)

        var lastError: Error?
        for attempt in 1...3 {
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                return
            } catch {
                lastError = error
                print("[ConversationService] audio session attempt \(attempt) failed: \(error)")
                try? await Task.sleep(for: .milliseconds(300 * attempt))
            }
        }
        throw lastError!
    }

    private func resetRecorders() {
        liveTranscript = ""
        audioLevel = 0
        silenceProgress = 0
        recorder.reset()
        scribeTranscriber.reset()
    }
}
