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

    private enum AppleSpeechOutcome {

        case transcript(String)

        case fallback(String)

        case failure(any Error)
    }

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

    private var fluidTranscriber = FluidTranscriber()

    private var stopRequested = false

    private var routeChangeObserver: (any NSObjectProtocol)?

    private var currentAudioRoutingMode: AudioRoutingMode = .nativeCarBluetooth

    private var currentEouTimeout: TimeInterval = 2.0

    private func systemLog(_ text: String) {
        messages.append(MessageModel(role: .system, text: text))
    }

    func prepareFluidModels() async throws {
        try await fluidTranscriber.loadModels()
    }

    func prepareScribeVad() async throws {
        try await scribeTranscriber.prepareVad()
    }

    func runTurn(config: AppConfig, playGreeting: Bool = false) async {
        stopRequested = false
        currentAudioRoutingMode = config.audioRoutingMode
        currentEouTimeout = max(0.5, config.eouTimeout)
        scribeTranscriber.onSystemLog = { [weak self] msg in self?.systemLog(msg) }
        streamingTTS.onSystemLog = { [weak self] msg in self?.systemLog(msg) }
        fluidTranscriber.onSystemLog = { [weak self] msg in self?.systemLog(msg) }
        do {
            try activateAudioSession()
            startRouteChangeObserver()
            systemLog("Audio session active")
            systemLog("Audio routing mode — \(currentAudioRoutingMode.label)")

            if playGreeting && GreetingCacheService.isCached {
                phase = .greeting
                systemLog("Playing greeting")
                try await GreetingCacheService.playGreeting()
            }

            while !stopRequested {
                let finalText = try await listen(config: config)
                let trimmedFinalText = finalText.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmedFinalText.isEmpty {
                    systemLog("Transcript captured (\(trimmedFinalText.count) chars)")
                } else {
                    systemLog("Transcript empty after listening")
                }

                if stopRequested {
                    if !trimmedFinalText.isEmpty {
                        systemLog("Stop requested before sending transcript")
                    }
                    resetRecorders()
                    break
                }

                guard !trimmedFinalText.isEmpty else {
                    resetRecorders()
                    continue
                }

                try await sendToOpenClaw(trimmedFinalText, config: config)
                resetRecorders()
            }
        } catch {
            systemLog("Error: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }

        stopRouteChangeObserver()
        resetRecorders()
        scribeTranscriber.stopEngine()
        systemLog("Stopped")
        phase = .idle
    }

    func stopListening() {
        stopRequested = true
        systemLog("Stop requested")
        stopCurrentInput()
        streamingTTS.disconnect()
        ttsPlayer.stop()
    }

    private func stopCurrentInput() {
        if fluidTranscriber.state == .recording {
            fluidTranscriber.stop()
        } else if scribeTranscriber.state == .recording {
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
        systemLog("Listening (\(config.transcriptionEngine.label))...")

        switch config.transcriptionEngine {
        case .fluid:
            return try await listenFluid()
        case .apple:
            return try await listenApple()
        case .scribe:
            return try await listenScribe(config: config)
        case .whisper:
            return try await listenWhisper(config: config)
        }
    }

    private func listenFluid() async throws -> String {
        try await fluidTranscriber.start(
            skipAudioSessionSetup: true,
            audioRoutingMode: currentAudioRoutingMode,
            eouTimeout: currentEouTimeout
        )

        startLiveUpdates(engine: .fluid)

        while fluidTranscriber.state == .recording {
            try await Task.sleep(for: .milliseconds(100))
        }

        return fluidTranscriber.finalTranscript
    }

    private func listenApple() async throws -> String {
        let speechStatus = await Transcriber.requestAuthorization()
        guard speechStatus == .authorized else {
            throw TranscriberError.permissionDenied
        }

        transcriber.cancel()
        try recorder.startRecording(
            skipAudioSessionSetup: false,
            audioRoutingMode: currentAudioRoutingMode,
            eouTimeout: currentEouTimeout
        )

        startLiveUpdates(engine: .apple)

        guard let request = recorder.recognitionRequest else {
            return ""
        }

        let outcome = await withTaskGroup(of: AppleSpeechOutcome.self) { group in
            group.addTask { [transcriber] in
                do {
                    let transcript = try await transcriber.transcribe(request: request)
                    return .transcript(transcript)
                } catch {
                    return .failure(error)
                }
            }

            group.addTask { [weak self] in
                guard let self else { return .fallback("") }

                while self.recorder.state == .recording {
                    if Task.isCancelled { return .fallback("") }
                    try? await Task.sleep(for: .milliseconds(100))
                }

                let deadline = Date().addingTimeInterval(0.9)
                while Date() < deadline {
                    if Task.isCancelled { return .fallback("") }
                    let partial = self.transcriber.partialResult
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !partial.isEmpty {
                        return .fallback(partial)
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }

                let partial = self.transcriber.partialResult
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return .fallback(partial)
            }

            var pendingFailure: (any Error)?

            while let next = await group.next() {
                switch next {
                case .transcript:
                    group.cancelAll()
                    return next
                case .fallback(let text):
                    group.cancelAll()
                    if text.isEmpty, let pendingFailure {
                        return .failure(pendingFailure)
                    }
                    return .fallback(text)
                case .failure(let error):
                    pendingFailure = error
                }
            }

            return pendingFailure.map { .failure($0) } ?? .fallback("")
        }

        let lastPartial = transcriber.partialResult
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if recorder.state == .recording {
            recorder.stopRecording()
        }
        transcriber.cancel()

        switch outcome {
        case .transcript(let text):
            return text
        case .fallback(let text):
            if !text.isEmpty {
                systemLog("Apple Speech: using partial transcript after EOU")
            }
            return text
        case .failure(let error):
            if !lastPartial.isEmpty {
                systemLog("Apple Speech: falling back to partial transcript after error: \(error.localizedDescription)")
                return lastPartial
            }
            if isNoSpeechAppleError(error) {
                systemLog("Apple Speech: no speech detected")
                return ""
            }
            if isTransientAppleSpeechError(error) {
                systemLog("Apple Speech: transient local recognition error")
                return ""
            }
            throw error
        }
    }

    private func isTransientAppleSpeechError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101
    }

    private func isNoSpeechAppleError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.localizedDescription.localizedCaseInsensitiveContains("no speech detected") {
            return true
        }
        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
            return true
        }
        return false
    }

    private func listenScribe(config: AppConfig) async throws -> String {
        try await scribeTranscriber.start(
            apiKey: config.elevenLabsAPIKey,
            eouTimeout: config.eouTimeout,
            skipAudioSessionSetup: true,
            audioRoutingMode: currentAudioRoutingMode
        )

        startLiveUpdates(engine: .scribe)

        while scribeTranscriber.state == .recording {
            try await Task.sleep(for: .milliseconds(100))
        }

        return scribeTranscriber.finalTranscript
    }

    private func listenWhisper(config: AppConfig) async throws -> String {
        try recorder.startRecording(
            saveToFile: true,
            skipAudioSessionSetup: true,
            audioRoutingMode: currentAudioRoutingMode,
            eouTimeout: currentEouTimeout
        )

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

    private var isSpeaking: Bool {
        if case .speaking = phase { return true }
        return false
    }

    private func startLiveUpdates(engine: TranscriptionEngine) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            while self.isListening {
                switch engine {
                case .fluid:
                    self.liveTranscript = self.fluidTranscriber.displayText
                    self.audioLevel = self.fluidTranscriber.audioLevel
                    self.silenceProgress = self.fluidTranscriber.silenceProgress
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

    private func startSpeakingUpdates() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            while self.isSpeaking {
                self.audioLevel = max(self.streamingTTS.audioLevel, self.ttsPlayer.audioLevel)
                self.silenceProgress = 0
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func sendToOpenClaw(_ finalText: String, config: AppConfig) async throws {
        messages.append(MessageModel(role: .user, text: finalText))
        phase = .processing
        systemLog("Sending to agent...")

        let hasTTS = config.hasTTS
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
                hasTTS: hasTTS,
                ttsProvider: config.ttsProvider,
                elevenLabsModel: config.ttsModel
            )

            systemLog("Streaming response...")
            var chunkBuffer = TextChunkBuffer()

            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    streamedText += delta
                    messages[messageIndex].text = streamedText

                    if hasTTS && !ttsConnected {
                        ttsConnected = true
                        streamingTTS.connect(config: config.ttsConfig)
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
                systemLog("Speaking...")
                startSpeakingUpdates()
                await streamingTTS.waitForPlaybackComplete()
                streamingTTS.disconnect()
                systemLog("Playback complete")
                audioLevel = 0
            }

        } catch {
            streamingRequestFailed = true
            streamingTTS.disconnect()
            ttsConnected = false
        }

        if streamingRequestFailed && streamedText.isEmpty {
            systemLog("Stream failed, retrying...")
            phase = .processing
            let response = try await OpenClawService.sendMessage(
                finalText,
                gatewayURL: config.gatewayURL,
                token: config.gatewayToken,
                hasTTS: hasTTS,
                ttsProvider: config.ttsProvider,
                elevenLabsModel: config.ttsModel
            )
            streamedText = response
            messages[messageIndex].text = response
        } else if streamedText.isEmpty {
            messages[messageIndex].text = "No response"
        }

        if hasTTS && !ttsConnected && !streamedText.isEmpty {
            phase = .speaking
            systemLog("Speaking...")
            startSpeakingUpdates()
            try await ttsPlayer.speak(
                streamedText,
                config: config.ttsConfig
            )
        }
    }

    private func activateAudioSession() throws {
        try AudioUtilities.activateVoiceCaptureSession(routingMode: currentAudioRoutingMode)

        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let inputs = route.inputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
        let outputs = route.outputs.map { "\($0.portType.rawValue)" }.joined(separator: ", ")
        let availableInputs = session.availableInputs?.map { $0.portType.rawValue }.joined(separator: ", ") ?? "none"
        systemLog("Audio route — in: [\(inputs)] out: [\(outputs)]")
        systemLog("Available inputs — [\(availableInputs)]")

        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
    }

    private func startRouteChangeObserver() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func stopRouteChangeObserver() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        if !didAudioRouteActuallyChange(notification) {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            refreshAudioSessionRouting(message: "Audio device connected")
            applyVoiceProcessingSetting()
        case .oldDeviceUnavailable:
            refreshAudioSessionRouting(message: "Audio device disconnected")
            applyVoiceProcessingSetting()
        case .routeConfigurationChange:
            refreshAudioSessionRouting(message: "Audio route reconfigured")
            applyVoiceProcessingSetting()
        default:
            break
        }
    }

    private func didAudioRouteActuallyChange(_ notification: Notification) -> Bool {
        guard let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey]
            as? AVAudioSessionRouteDescription
        else {
            return true
        }

        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        return routeSignature(previousRoute) != routeSignature(currentRoute)
    }

    private func routeSignature(_ route: AVAudioSessionRouteDescription) -> String {
        let inputs = route.inputs.map { "\($0.portType.rawValue):\($0.uid)" }.joined(separator: "|")
        let outputs = route.outputs.map { "\($0.portType.rawValue):\($0.uid)" }.joined(separator: "|")
        return "in[\(inputs)]out[\(outputs)]"
    }

    private func applyVoiceProcessingSetting() {
        if fluidTranscriber.state == .recording {
            fluidTranscriber.updateVoiceProcessing()
        } else if scribeTranscriber.state == .recording {
            scribeTranscriber.updateVoiceProcessing()
        } else if recorder.state == .recording {
            recorder.updateVoiceProcessing()
        }
    }

    private func refreshAudioSessionRouting(message: String) {
        do {
            try AudioUtilities.activateVoiceCaptureSession(routingMode: currentAudioRoutingMode)
        } catch {
            systemLog("\(message) — reroute failed: \(error.localizedDescription)")
        }

        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let inputs = route.inputs.map { $0.portType.rawValue }.joined(separator: ", ")
        let outputs = route.outputs.map { $0.portType.rawValue }.joined(separator: ", ")
        let availableInputs = session.availableInputs?.map { $0.portType.rawValue }.joined(separator: ", ") ?? "none"
        systemLog("\(message) — in: [\(inputs)] out: [\(outputs)]")
        systemLog("Available inputs — [\(availableInputs)]")
    }

    private func resetRecorders() {
        liveTranscript = ""
        audioLevel = 0
        silenceProgress = 0
        recorder.reset()
        scribeTranscriber.reset()
        fluidTranscriber.reset()
    }
}
