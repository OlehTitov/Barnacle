//
//  AuthStep.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct AuthStep: View {

    @Environment(AppConfig.self)
    private var config

    var onNext: () -> Void
    var onBack: () -> Void

    @State
    private var tokenInput = ""

    @State
    private var isValidating = false

    @State
    private var validationResult: ValidationResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Authenticate")
                    .font(.largeTitle.bold())

                Text("Enter your OpenClaw hooks token to authenticate requests.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hooks Token")
                        .font(.headline)

                    SecureField("Enter your token", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }

                if let result = validationResult {
                    switch result {
                    case .success:
                        Label("Authenticated successfully", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("How to get your token")
                        .font(.headline)

                    Text("1. Open your OpenClaw dashboard")
                    Text("2. Navigate to Settings > Webhooks")
                    Text("3. Enable webhooks and copy the token")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer(minLength: 20)

                HStack {
                    Button("Back") { onBack() }

                    Spacer()

                    Button("Test Auth") {
                        validate()
                    }
                    .disabled(tokenInput.isEmpty || isValidating)

                    Button("Next") {
                        config.hooksToken = tokenInput
                        config.save()
                        onNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(validationResult == nil || isValidating)
                }
            }
            .padding()
        }
        .onAppear {
            tokenInput = config.hooksToken
        }
    }

    private func validate() {
        isValidating = true
        validationResult = nil
        Task {
            do {
                try await OpenClawService.validateAuth(
                    gatewayURL: config.gatewayURL,
                    token: tokenInput
                )
                validationResult = .success
            } catch {
                validationResult = .failure(error.localizedDescription)
            }
            isValidating = false
        }
    }
}
