//
//  VoiceStep.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct VoiceStep: View {

    @Environment(AppConfig.self)
    private var config

    var onDone: () -> Void
    var onBack: () -> Void

    @State
    private var apiKeyInput = ""

    @State
    private var voiceIDInput = ""

    @State
    private var isTesting = false

    @State
    private var testResult: ValidationResult?

    private let ttsPlayer = TTSPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Voice Setup")
                    .font(.largeTitle.bold())

                Text("Configure ElevenLabs for text-to-speech. You can skip this for text-only mode.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ElevenLabs API Key")
                        .font(.headline)

                    SecureField("Enter your API key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice ID")
                        .font(.headline)

                    TextField("Enter voice ID", text: $voiceIDInput)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let result = testResult {
                    switch result {
                    case .success:
                        Label("Voice test successful", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Button("Test Voice") {
                    testVoice()
                }
                .disabled(apiKeyInput.isEmpty || voiceIDInput.isEmpty || isTesting)

                Spacer(minLength: 20)

                HStack {
                    Button("Back") { onBack() }

                    Spacer()

                    Button("Skip") {
                        onDone()
                    }

                    Button("Done") {
                        config.elevenLabsAPIKey = apiKeyInput
                        config.voiceID = voiceIDInput
                        config.save()
                        onDone()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            apiKeyInput = config.elevenLabsAPIKey
            voiceIDInput = config.voiceID
        }
    }

    private func testVoice() {
        isTesting = true
        testResult = nil
        Task {
            do {
                try await ttsPlayer.speak(
                    "Hello, I'm your assistant",
                    config: TTSConfig(
                        provider: .elevenLabs,
                        apiKey: apiKeyInput,
                        voiceID: voiceIDInput,
                        modelID: TTSModel.v3.rawValue,
                        stability: TTSStability.natural.rawValue,
                        similarityBoost: 0.8,
                        style: 0.4,
                        openAIAPIKey: "",
                        openAIVoice: "",
                        openAIVoiceInstructions: ""
                    )
                )
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
