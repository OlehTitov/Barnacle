//
//  ConversationView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct ConversationView: View {

    let messages: [MessageModel]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        HStack {
                            if message.role == .user { Spacer(minLength: 60) }

                            Text(message.text)
                                .padding(12)
                                .background(
                                    message.role == .user
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundStyle(message.role == .user ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                            if message.role == .assistant { Spacer(minLength: 60) }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
