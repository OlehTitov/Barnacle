//
//  MessageBubbleView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI
import UIKit

struct MessageBubbleView: View {

    @Environment(AppConfig.self)
    private var config

    let message: MessageModel

    var body: some View {
        Text(formattedText)
            .font(config.displayFont.font(size: config.displayFontSize))
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
        let text = config.displayAllCaps ? message.text.uppercased() : message.text
        return "\(prefix) \(text)"
    }
}
