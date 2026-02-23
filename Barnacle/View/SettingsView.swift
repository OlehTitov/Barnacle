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
    private var hooksToken = ""

    @State
    private var elevenLabsAPIKey = ""

    @State
    private var voiceID = ""

    @State
    private var testStatus: String?

    @State
    private var isTesting = false

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

                LabeledContent("Hooks Token") {
                    SecureField("Token", text: $hooksToken)
                        .multilineTextAlignment(.trailing)
                }

                Button("Test Connection") {
                    testConnection()
                }
                .disabled(gatewayURL.isEmpty || hooksToken.isEmpty || isTesting)

                if let status = testStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("Success") ? .green : .red)
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
                    config.hooksToken = hooksToken
                    config.elevenLabsAPIKey = elevenLabsAPIKey
                    config.voiceID = voiceID
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
            hooksToken = config.hooksToken
            elevenLabsAPIKey = config.elevenLabsAPIKey
            voiceID = config.voiceID
        }
    }

    private func testConnection() {
        isTesting = true
        testStatus = nil
        Task {
            do {
                try await OpenClawService.validateAuth(
                    gatewayURL: gatewayURL,
                    token: hooksToken
                )
                testStatus = "Success - Connected!"
            } catch {
                testStatus = "Failed: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
