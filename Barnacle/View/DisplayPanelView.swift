//
//  DisplayPanelView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct DisplayPanelView: View {

    let conversation: ConversationService

    let appState: AppState

    var body: some View {
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
}
