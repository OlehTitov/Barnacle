//
//  MessageBubbleView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI
import UIKit

struct MessageBubbleView: View {

    let message: MessageModel

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.text)
                .font(message.role == .assistant ? BarnacleTheme.monoBody : .body)
                .foregroundStyle(.white)
                .padding(14)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: BarnacleTheme.cornerRadius))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: message.text) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: Color {
        message.role == .user ? BarnacleTheme.coral : BarnacleTheme.surface
    }
}
