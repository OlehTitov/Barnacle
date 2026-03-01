//
//  StatusLedView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct StatusLedView: View {

    let appState: AppState

    var body: some View {
        Circle()
            .fill(ledColor)
            .frame(width: 14, height: 14)
            .shadow(color: glowColor, radius: glowRadius)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .opacity(isPulsing ? 0.7 : 1.0)
    }

    private var ledColor: Color {
        switch appState {
        case .idle:
            BarnacleTheme.ledIdle
        case .recording, .speaking:
            BarnacleTheme.accent
        case .processing, .streaming:
            BarnacleTheme.accent
        case .error:
            .red
        }
    }

    private var glowColor: Color {
        switch appState {
        case .idle:
            .clear
        case .recording, .speaking:
            BarnacleTheme.accent.opacity(0.6)
        case .processing, .streaming:
            BarnacleTheme.accent.opacity(0.4)
        case .error:
            .red.opacity(0.4)
        }
    }

    private var glowRadius: CGFloat {
        switch appState {
        case .idle:
            0
        case .recording, .speaking:
            6
        case .processing, .streaming:
            4
        case .error:
            4
        }
    }

    private var isPulsing: Bool {
        switch appState {
        case .processing, .streaming:
            true
        default:
            false
        }
    }
}
