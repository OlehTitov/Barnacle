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

    @State
    private var isPressed = false

    private let micSize: CGFloat = 120

    private let bezelSize: CGFloat = 126

    private let socketSize: CGFloat = 130

    var body: some View {
        ZStack {
            if isRecording && !reduceMotion {
                Circle()
                    .fill(BarnacleTheme.accent.opacity(0.15))
                    .frame(width: glowSize, height: glowSize)
                    .blur(radius: 20)
            }

            if isRecording {
                SilenceRingView(progress: silenceProgress)
                    .frame(
                        width: micSize + 16,
                        height: micSize + 16
                    )
            }

            // 1. Socket — recessed groove
            Circle()
                .fill(BarnacleTheme.buttonSocketInner)
                .frame(width: socketSize, height: socketSize)
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(Circle())
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.clear, .clear, .white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )

            // 2. Bezel ring
            Circle()
                .fill(BarnacleTheme.buttonBase)
                .frame(width: bezelSize, height: bezelSize)

            // 3. Accent dome
            Circle()
                .fill(buttonColor)
                .frame(width: micSize, height: micSize)
                .shadow(
                    color: buttonColor.opacity(0.4),
                    radius: isRecording ? 20 : 8
                )
                .scaleEffect(isRecording && !reduceMotion ? 1.05 : 1.0)
                // 4. Rim stroke
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: isPressed)

            // 5. Icon
            MicIconView(appState: appState)
                .font(.system(size: 44 as CGFloat))
                .foregroundStyle(.white)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: isPressed)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if !isDisabled {
                        action()
                    }
                }
        )
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
        case .idle: BarnacleTheme.accent
        case .recording: BarnacleTheme.accent
        case .processing: BarnacleTheme.accent.opacity(0.6)
        case .streaming: BarnacleTheme.accent.opacity(0.6)
        case .speaking: BarnacleTheme.accent.opacity(0.6)
        case .error: .red.opacity(0.6)
        }
    }

    private var glowSize: CGFloat {
        micSize + CGFloat(audioLevel) * 60
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
