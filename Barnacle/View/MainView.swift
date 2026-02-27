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

    var body: some View {
        NavigationStack {
            ZStack {
                BarnacleTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ConversationView(messages: conversation.messages)

                    if !conversation.liveTranscript.isEmpty {
                        Text(conversation.liveTranscript)
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
                        audioLevel: conversation.audioLevel,
                        silenceProgress: conversation.silenceProgress,
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
            }
            .onReceive(NotificationCenter.default.publisher(for: .barnacleIntentTriggered)) { _ in
                guard config.transcriptionEngine != .fluid || fluidModels.isReady else { return }
                Task { await conversation.runTurn(config: config, playGreeting: true) }
            }
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
