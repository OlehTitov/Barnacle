//
//  MicButtonView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct MicButtonView: View {

    let appState: AppState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: buttonColor.opacity(0.4),
                        radius: pulseRadius
                    )

                MicIconView(appState: appState)
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
        }
        .disabled(isDisabled)
        .animation(
            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
            value: isRecording
        )
    }

    private var buttonColor: Color {
        switch appState {
        case .idle: .accentColor
        case .recording: .red
        case .processing: .orange
        case .speaking: .green
        case .error: .red.opacity(0.6)
        }
    }

    private var pulseRadius: CGFloat {
        isRecording ? 20 : 8
    }

    private var isRecording: Bool {
        if case .recording = appState { return true }
        return false
    }

    private var isDisabled: Bool {
        switch appState {
        case .processing, .speaking: true
        default: false
        }
    }
}
