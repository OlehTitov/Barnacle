//
//  MainView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI
import UIKit

struct MainView: View {

    @Environment(AppConfig.self)
    private var config

    @State
    private var conversation = ConversationService()

    @State
    private var fluidModels = FluidModelService()

    @State
    private var showSettings = false

    private var appState: AppState {
        switch conversation.phase {
        case .idle, .finished:
            return .idle
        case .greeting:
            return .speaking
        case .listening:
            return .recording
        case .processing:
            return .processing
        case .speaking:
            return .speaking
        case .failed(let message):
            return .error(message)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    var body: some View {
        ZStack {
            BarnacleTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                DisplayPanelView(conversation: conversation, appState: appState)

                Spacer()

                controlBar
                    .padding()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .overlay {
            if config.transcriptionEngine == .fluid && !fluidModels.isReady {
                ModelDownloadView(
                    isPreparing: fluidModels.isPreparing,
                    errorMessage: fluidModels.errorMessage,
                    retryAction: { Task { await fluidModels.prepareIfNeeded(using: conversation) } }
                )
            }
        }
        .task(id: config.transcriptionEngine) {
            if config.transcriptionEngine == .fluid {
                await fluidModels.prepareIfNeeded(using: conversation)
            }
            try? await conversation.prepareScribeVad()
        }
        .onReceive(NotificationCenter.default.publisher(for: .barnacleIntentTriggered)) { _ in
            guard config.transcriptionEngine != .fluid || fluidModels.isReady else { return }
            Task { await conversation.runTurn(config: config, playGreeting: true) }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("BARNACLE")
                    .font(BarnacleTheme.monoTitle)
                    .foregroundStyle(BarnacleTheme.textPrimary)

                Text("v\(appVersion)")
                    .font(BarnacleTheme.monoCaption)
                    .foregroundStyle(BarnacleTheme.textPrimary.opacity(0.5))
            }

            Spacer()

            DotMatrixView()

            Spacer()

            StatusLedView(appState: appState)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 32) {
            PowerButtonView(appState: appState, action: { handleMicTap() })

            VolumeControlView(appState: appState)

            SettingsButtonView(appState: appState, action: { showSettings = true })
        }
    }

    private func handleMicTap() {
        if config.transcriptionEngine == .fluid && !fluidModels.isReady {
            return
        }

        switch conversation.phase {
        case .idle, .finished, .failed:
            SFXPlayer.play("startup-sound")
            Task { await conversation.runTurn(config: config) }
        default:
            SFXPlayer.play("power-off")
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                conversation.stopListening()
            }
        }
    }
}
