//
//  MicButtonView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct MicButtonView: View {

    let appState: AppState
    let audioLevel: Float
    let silenceProgress: Double
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording && !reduceMotion {
                    Circle()
                        .fill(BarnacleTheme.coral.opacity(0.15))
                        .frame(width: glowSize, height: glowSize)
                        .blur(radius: 20)
                }

                if isRecording {
                    SilenceRingView(progress: silenceProgress)
                        .frame(
                            width: BarnacleTheme.micButtonSize + 16,
                            height: BarnacleTheme.micButtonSize + 16
                        )
                }

                Circle()
                    .fill(buttonColor)
                    .frame(
                        width: BarnacleTheme.micButtonSize,
                        height: BarnacleTheme.micButtonSize
                    )
                    .shadow(
                        color: buttonColor.opacity(0.4),
                        radius: isRecording ? 20 : 8
                    )
                    .scaleEffect(isRecording && !reduceMotion ? 1.05 : 1.0)

                MicIconView(appState: appState)
                    .font(.system(size: BarnacleTheme.micIconSize))
                    .foregroundStyle(.white)
            }
        }
        .disabled(isDisabled)
        .animation(
            reduceMotion
                ? .none
                : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
            value: isRecording
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var buttonColor: Color {
        switch appState {
        case .idle: BarnacleTheme.coral
        case .recording: BarnacleTheme.coral
        case .processing: BarnacleTheme.coral.opacity(0.6)
        case .streaming: BarnacleTheme.coral.opacity(0.6)
        case .speaking: BarnacleTheme.coral.opacity(0.6)
        case .error: .red.opacity(0.6)
        }
    }

    private var glowSize: CGFloat {
        BarnacleTheme.micButtonSize + CGFloat(audioLevel) * 60
    }

    private var isRecording: Bool {
        if case .recording = appState { return true }
        return false
    }

    private var isDisabled: Bool {
        switch appState {
        case .processing, .streaming, .speaking: true
        default: false
        }
    }

    private var accessibilityLabel: String {
        switch appState {
        case .idle: "Microphone"
        case .recording: "Recording"
        case .processing: "Processing"
        case .streaming: "Streaming"
        case .speaking: "Speaking"
        case .error: "Error"
        }
    }

    private var accessibilityHint: String {
        switch appState {
        case .idle: "Tap to start recording"
        case .recording: "Tap to stop recording"
        case .processing: "Waiting for response"
        case .streaming: "Receiving response"
        case .speaking: "Playing response"
        case .error: "Tap to try again"
        }
    }
}
