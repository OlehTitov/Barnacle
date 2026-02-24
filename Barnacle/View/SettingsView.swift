//
//  SettingsView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppConfig.self)
    private var config

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var gatewayURL = ""

    @State
    private var gatewayToken = ""

    @State
    private var elevenLabsAPIKey = ""

    @State
    private var voiceID = ""

    @State
    private var ttsStability: TTSStability = .natural

    @State
    private var similarityBoost: Double = 0.8

    @State
    private var style: Double = 0.4

    @State
    private var testStatus: String?

    @State
    private var isTesting = false

    @State
    private var transcriptionEngine: TranscriptionEngine = .apple

    @State
    private var whisperModel: WhisperModel = .whisper1

    @State
    private var openAIAPIKey = ""

    @State
    private var isGeneratingGreeting = false

    @State
    private var greetingStatus: String?

    var body: some View {
        Form {
            Section("OpenClaw Connection") {
                LabeledContent("Gateway URL") {
                    TextField("https://...", text: $gatewayURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Gateway Token") {
                    SecureField("Token", text: $gatewayToken)
                        .multilineTextAlignment(.trailing)
                }

                Button("Test Connection") {
                    testConnection()
                }
                .disabled(gatewayURL.isEmpty || gatewayToken.isEmpty || isTesting)

                if let status = testStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("Success") ? .green : .red)
                }
            }

            Section("Transcription") {
                Picker("Engine", selection: $transcriptionEngine) {
                    ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
                        Text(engine.label).tag(engine)
                    }
                }

                if transcriptionEngine == .whisper {
                    Picker("Model", selection: $whisperModel) {
                        ForEach(WhisperModel.allCases, id: \.self) { model in
                            Text(model.label).tag(model)
                        }
                    }

                    LabeledContent("OpenAI API Key") {
                        SecureField("API Key", text: $openAIAPIKey)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section("Voice (ElevenLabs)") {
                LabeledContent("API Key") {
                    SecureField("API Key", text: $elevenLabsAPIKey)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Voice ID") {
                    TextField("Voice ID", text: $voiceID)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Stability", selection: $ttsStability) {
                    ForEach(TTSStability.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Similarity Boost")
                        Spacer()
                        Text(String(format: "%.1f", similarityBoost))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $similarityBoost, in: 0...1, step: 0.1)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Style")
                        Spacer()
                        Text(String(format: "%.1f", style))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $style, in: 0...1, step: 0.1)
                }

                Button {
                    generateGreeting()
                } label: {
                    HStack {
                        Text("Generate Greeting")
                        Spacer()
                        if isGeneratingGreeting {
                            ProgressView()
                        } else if GreetingCacheService.isCached {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(elevenLabsAPIKey.isEmpty || voiceID.isEmpty || isGeneratingGreeting)

                if let status = greetingStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("Cached") ? .green : .red)
                }
            }

            Section {
                Button("Re-run Onboarding") {
                    config.isOnboarded = false
                    config.save()
                    dismiss()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    config.gatewayURL = gatewayURL
                    config.gatewayToken = gatewayToken
                    config.elevenLabsAPIKey = elevenLabsAPIKey
                    config.voiceID = voiceID
                    config.ttsStability = ttsStability
                    config.ttsSimilarityBoost = similarityBoost
                    config.ttsStyle = style
                    config.transcriptionEngine = transcriptionEngine
                    config.whisperModel = whisperModel
                    config.openAIAPIKey = openAIAPIKey
                    config.save()
                    dismiss()
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            gatewayURL = config.gatewayURL
            gatewayToken = config.gatewayToken
            elevenLabsAPIKey = config.elevenLabsAPIKey
            voiceID = config.voiceID
            ttsStability = config.ttsStability
            similarityBoost = config.ttsSimilarityBoost
            style = config.ttsStyle
            transcriptionEngine = config.transcriptionEngine
            whisperModel = config.whisperModel
            openAIAPIKey = config.openAIAPIKey
        }
    }

    private func generateGreeting() {
        isGeneratingGreeting = true
        greetingStatus = nil
        Task {
            do {
                try await GreetingCacheService.ensureCached(
                    apiKey: elevenLabsAPIKey,
                    voiceID: voiceID,
                    stability: ttsStability.rawValue,
                    similarityBoost: similarityBoost,
                    style: style
                )
                greetingStatus = "Cached"
            } catch {
                greetingStatus = "Failed: \(error.localizedDescription)"
            }
            isGeneratingGreeting = false
        }
    }

    private func testConnection() {
        isTesting = true
        testStatus = nil
        Task {
            do {
                try await OpenClawService.validateAuth(
                    gatewayURL: gatewayURL,
                    token: gatewayToken
                )
                testStatus = "Success - Connected!"
            } catch {
                testStatus = "Failed: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
