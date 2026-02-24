//
//  MainView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI
import AVFoundation
import Speech
import UIKit

struct MainView: View {

    @Environment(AppConfig.self)
    private var config

    @State
    private var appState: AppState = .idle

    @State
    private var messages: [MessageModel] = []

    @State
    private var showSettings = false

    @State
    private var recorder = VoiceRecorder()

    @State
    private var transcriber = Transcriber()

    @State
    private var ttsPlayer = TTSPlayer()

    @State
    private var streamingTTS = StreamingTTSPlayer()

    var body: some View {
        NavigationStack {
            ZStack {
                BarnacleTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ConversationView(messages: messages)

                    if !transcriber.partialResult.isEmpty {
                        Text(transcriber.partialResult)
                            .font(BarnacleTheme.monoCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    if case .error(let message) = appState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }

                    Spacer()

                    MicButtonView(
                        appState: appState,
                        audioLevel: recorder.audioLevel,
                        silenceProgress: recorder.silenceProgress,
                        action: { handleMicTap() }
                    )
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Barnacle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    private func handleMicTap() {
        switch appState {
        case .recording:
            recorder.stopRecording()
        case .idle, .error:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            startListening()
        default:
            break
        }
    }

    private func startListening() {
        Task {
            let micStatus = AVAudioApplication.shared.recordPermission
            if micStatus == .undetermined {
                let granted = await AVAudioApplication.requestRecordPermission()
                guard granted else {
                    appState = .error("Microphone permission denied")
                    return
                }
            } else if micStatus == .denied {
                appState = .error("Microphone permission denied")
                return
            }

            let speechStatus = await Transcriber.requestAuthorization()
            guard speechStatus == .authorized else {
                appState = .error("Speech recognition permission denied")
                return
            }

            do {
                transcriber.cancel()
                try recorder.startRecording()
                appState = .recording

                guard let request = recorder.recognitionRequest else { return }

                let finalText = try await transcriber.transcribe(request: request)
                transcriber.cancel()

                guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    recorder.reset()
                    appState = .idle
                    return
                }

                messages.append(MessageModel(role: .user, text: finalText))
                appState = .processing

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

                    appState = .streaming

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
                        appState = .speaking
                        await streamingTTS.waitForPlaybackComplete()
                        streamingTTS.disconnect()
                    }

                } catch {
                    streamingRequestFailed = true
                    streamingTTS.disconnect()
                    ttsConnected = false
                }

                if streamingRequestFailed && streamedText.isEmpty {
                    appState = .processing
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
                    appState = .speaking
                    try await ttsPlayer.speak(
                        streamedText,
                        apiKey: config.elevenLabsAPIKey,
                        voiceID: config.voiceID,
                        stability: config.ttsStability.rawValue,
                        similarityBoost: config.ttsSimilarityBoost,
                        style: config.ttsStyle
                    )
                }

                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appState = .idle
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                appState = .error(error.localizedDescription)
            }

            recorder.reset()
        }
    }
}
