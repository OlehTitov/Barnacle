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
            .onReceive(NotificationCenter.default.publisher(for: .barnacleIntentTriggered)) { _ in
                Task { await conversation.runTurn(config: config, playGreeting: true) }
            }
        }
    }

    private func handleMicTap() {
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
