//
//  ConversationView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct ConversationView: View {

    let messages: [MessageModel]

    let liveTranscript: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if !liveTranscript.isEmpty {
                        Text(liveTranscript.uppercased())
                            .font(BarnacleTheme.monoCaption)
                            .foregroundStyle(BarnacleTheme.accent.opacity(0.6))
                            .padding(.top, 4)
                            .id("liveTranscript")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: liveTranscript) {
                if !liveTranscript.isEmpty {
                    withAnimation {
                        proxy.scrollTo("liveTranscript", anchor: .bottom)
                    }
                }
            }
        }
    }
}
