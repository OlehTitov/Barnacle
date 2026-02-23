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

                guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    recorder.reset()
                    appState = .idle
                    return
                }

                messages.append(MessageModel(role: .user, text: finalText))
                appState = .processing

                let response = try await OpenClawService.sendMessage(
                    finalText,
                    gatewayURL: config.gatewayURL,
                    token: config.gatewayToken
                )

                messages.append(MessageModel(role: .assistant, text: response))
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                if !config.elevenLabsAPIKey.isEmpty && !config.voiceID.isEmpty {
                    appState = .speaking
                    try await ttsPlayer.speak(
                        response,
                        apiKey: config.elevenLabsAPIKey,
                        voiceID: config.voiceID
                    )
                }

                appState = .idle
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                appState = .error(error.localizedDescription)
            }

            recorder.reset()
        }
    }
}
