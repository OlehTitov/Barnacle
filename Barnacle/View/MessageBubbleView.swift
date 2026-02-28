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
        Text(formattedText)
            .font(BarnacleTheme.monoBody)
            .foregroundStyle(BarnacleTheme.textPrimary)
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
    }

    private var formattedText: String {
        let prefix = message.role == .user ? "[USER]" : "[AGENT]"
        return "\(prefix) \(message.text.uppercased())"
    }
}
