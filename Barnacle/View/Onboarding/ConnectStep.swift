//
//  ConnectStep.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct ConnectStep: View {

    @Environment(AppConfig.self)
    private var config

    var onNext: () -> Void

    @State
    private var urlInput = ""

    @State
    private var isValidating = false

    @State
    private var validationResult: ValidationResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Connect to OpenClaw")
                    .font(.largeTitle.bold())

                Text("Enter your OpenClaw gateway URL. This is typically your Tailscale machine address running OpenClaw.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gateway URL")
                        .font(.headline)

                    TextField("https://your-machine.tail1234.ts.net", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { validate() }
                }

                if let result = validationResult {
                    switch result {
                    case .success:
                        Label("Connected successfully", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup Instructions")
                        .font(.headline)

                    Text("1. Install Tailscale on your device and the machine running OpenClaw")
                    Text("2. Ensure both devices are on the same Tailscale network")
                    Text("3. Use the Tailscale address of your OpenClaw instance")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer(minLength: 20)

                HStack {
                    Button("Test Connection") {
                        validate()
                    }
                    .disabled(urlInput.isEmpty || isValidating)

                    Spacer()

                    Button("Next") {
                        config.gatewayURL = urlInput.trimmingCharacters(
                            in: CharacterSet(charactersIn: "/")
                        )
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
            urlInput = config.gatewayURL
        }
    }

    private func validate() {
        isValidating = true
        validationResult = nil
        let url = urlInput.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        Task {
            do {
                try await OpenClawService.validateConnection(gatewayURL: url)
                validationResult = .success
            } catch {
                validationResult = .failure(error.localizedDescription)
            }
            isValidating = false
        }
    }
}
