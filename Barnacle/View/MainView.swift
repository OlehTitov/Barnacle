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

                displayPanel

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

    private var displayPanel: some View {
        VStack(spacing: 0) {
            ConversationView(
                messages: conversation.messages,
                liveTranscript: conversation.liveTranscript
            )

            if case .error(let message) = appState {
                Text(message)
                    .font(BarnacleTheme.monoCaption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            AudioLevelBarView(
                audioLevel: conversation.audioLevel,
                silenceProgress: conversation.silenceProgress,
                appState: appState
            )
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .background(BarnacleTheme.displayBackground)
        .clipShape(RoundedRectangle(cornerRadius: BarnacleTheme.displayCornerRadius))
        .padding(.horizontal, 16)
    }

    private var controlBar: some View {
        HStack(spacing: 32) {
            PowerButtonView(appState: appState, action: { handleMicTap() })

            VolumeControlView()

            SettingsButtonView(action: { showSettings = true })
        }
    }

    private func handleMicTap() {
        if config.transcriptionEngine == .fluid && !fluidModels.isReady {
            return
        }

        switch conversation.phase {
        case .listening:
            conversation.stopListening()
        case .idle, .finished, .failed:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await conversation.runTurn(config: config) }
        default:
            break
        }
    }
}
