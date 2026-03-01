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
    private var ttsProvider: TTSProvider = .elevenLabs

    @State
    private var ttsModel: TTSModel = .v3

    @State
    private var ttsStability: TTSStability = .natural

    @State
    private var similarityBoost: Double = 0.8

    @State
    private var style: Double = 0.4

    @State
    private var elevenLabsSpeed: Double = 1.0

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
    private var openAIVoice: OpenAIVoice = .coral

    @State
    private var openAIVoiceInstructions = ""

    @State
    private var openAISpeed: Double = 1.0

    @State
    private var displayFont: GeistPixelFont = .square

    @State
    private var displayFontSize: Double = 14

    @State
    private var displayAllCaps = true

    @State
    private var visualTheme: VisualTheme = .midnight

    @State
    private var showDebugMessages = false

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

            Section("Appearance") {
                Picker("Theme", selection: $visualTheme) {
                    ForEach(VisualTheme.allCases, id: \.self) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
            }

            Section("Display") {
                Picker("Font", selection: $displayFont) {
                    ForEach(GeistPixelFont.allCases, id: \.self) { font in
                        Text(font.label).tag(font)
                    }
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(displayFontSize))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $displayFontSize, in: 10...24, step: 1)
                }

                Toggle("All Caps", isOn: $displayAllCaps)

                Toggle("Show Debug Messages", isOn: $showDebugMessages)

                Text("PREVIEW TEXT")
                    .font(displayFont.font(size: displayFontSize))
                    .foregroundStyle(BarnacleTheme.textPrimary)
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

            Section("Voice") {
                Picker("TTS Provider", selection: $ttsProvider) {
                    ForEach(TTSProvider.allCases, id: \.self) { provider in
                        Text(provider.label).tag(provider)
                    }
                }

                if ttsProvider == .elevenLabs {
                    LabeledContent("API Key") {
                        SecureField("API Key", text: $elevenLabsAPIKey)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Model", selection: $ttsModel) {
                        ForEach(TTSModel.allCases, id: \.self) { model in
                            Text(model.label).tag(model)
                        }
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

                    if ttsModel != .v3 {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Text(String(format: "%.1f", elevenLabsSpeed))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $elevenLabsSpeed, in: 0.7...1.2, step: 0.1)
                        }
                    }
                }

                if ttsProvider == .openAI {
                    LabeledContent("OpenAI API Key") {
                        SecureField("API Key", text: $openAIAPIKey)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Voice", selection: $openAIVoice) {
                        ForEach(OpenAIVoice.allCases, id: \.self) { voice in
                            Text(voice.label).tag(voice)
                        }
                    }

                    LabeledContent("Voice Instructions") {
                        TextField("e.g. Speak warmly", text: $openAIVoiceInstructions)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(String(format: "%.2f", openAISpeed))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $openAISpeed, in: 0.25...4.0, step: 0.25)
                    }
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
                .disabled(greetingDisabled)

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
                    config.ttsProvider = ttsProvider
                    config.ttsModel = ttsModel
                    config.ttsStability = ttsStability
                    config.ttsSimilarityBoost = similarityBoost
                    config.ttsStyle = style
                    config.elevenLabsSpeed = elevenLabsSpeed
                    config.openAIVoice = openAIVoice
                    config.openAIVoiceInstructions = openAIVoiceInstructions
                    config.openAISpeed = openAISpeed
                    config.transcriptionEngine = transcriptionEngine
                    config.whisperModel = whisperModel
                    config.openAIAPIKey = openAIAPIKey
                    config.displayFont = displayFont
                    config.displayFontSize = displayFontSize
                    config.displayAllCaps = displayAllCaps
                    config.visualTheme = visualTheme
                    config.showDebugMessages = showDebugMessages
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
            ttsProvider = config.ttsProvider
            ttsModel = config.ttsModel
            ttsStability = config.ttsStability
            similarityBoost = config.ttsSimilarityBoost
            style = config.ttsStyle
            elevenLabsSpeed = config.elevenLabsSpeed
            openAIVoice = config.openAIVoice
            openAIVoiceInstructions = config.openAIVoiceInstructions
            openAISpeed = config.openAISpeed
            transcriptionEngine = config.transcriptionEngine
            whisperModel = config.whisperModel
            openAIAPIKey = config.openAIAPIKey
            displayFont = config.displayFont
            displayFontSize = config.displayFontSize
            displayAllCaps = config.displayAllCaps
            visualTheme = config.visualTheme
            showDebugMessages = config.showDebugMessages
        }
    }

    private var greetingDisabled: Bool {
        if isGeneratingGreeting { return true }
        switch ttsProvider {
        case .elevenLabs:
            return elevenLabsAPIKey.isEmpty || voiceID.isEmpty
        case .openAI:
            return openAIAPIKey.isEmpty
        }
    }

    private func generateGreeting() {
        isGeneratingGreeting = true
        greetingStatus = nil
        Task {
            do {
                try await GreetingCacheService.ensureCached(
                    config: TTSConfig(
                        provider: ttsProvider,
                        apiKey: elevenLabsAPIKey,
                        voiceID: voiceID,
                        modelID: ttsModel.rawValue,
                        stability: ttsStability.rawValue,
                        similarityBoost: similarityBoost,
                        style: style,
                        elevenLabsSpeed: elevenLabsSpeed,
                        openAIAPIKey: openAIAPIKey,
                        openAIVoice: openAIVoice.rawValue,
                        openAIVoiceInstructions: openAIVoiceInstructions,
                        openAISpeed: openAISpeed
                    )
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
