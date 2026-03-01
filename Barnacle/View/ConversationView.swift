//
//  ConversationView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct ConversationView: View {

    @Environment(AppConfig.self)
    private var config

    let messages: [MessageModel]

    let liveTranscript: String

    private var visibleMessages: [MessageModel] {
        config.showDebugMessages ? messages : messages.filter { $0.role != .system }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleMessages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if !liveTranscript.isEmpty {
                        Text(displayTranscript)
                            .font(config.displayFont.font(size: config.displayFontSize))
                            .foregroundStyle(BarnacleTheme.accent.opacity(0.6))
                            .padding(.top, 4)
                            .id("liveTranscript")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: visibleMessages.count) {
                if let last = visibleMessages.last {
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

    private var displayTranscript: String {
        config.displayAllCaps ? liveTranscript.uppercased() : liveTranscript
    }
}
