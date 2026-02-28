//
//  PowerButtonView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct PowerButtonView: View {

    let appState: AppState

    let action: () -> Void

    private let size = BarnacleTheme.controlButtonSize

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: size, height: size)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [BarnacleTheme.buttonSurface, Color(red: 0.08, green: 0.09, blue: 0.11)],
                                center: .center,
                                startRadius: 0,
                                endRadius: (size - 6) / 2
                            )
                        )
                        .frame(width: size - 6, height: size - 6)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(white: 0.35), Color(white: 0.08)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: "power")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isPoweredOn ? .white : Color(white: 0.4))
                        .shadow(color: isPoweredOn ? .white.opacity(0.5) : .clear, radius: 4)
                }
            }
            .disabled(isDisabled)

            Text("POWER")
                .font(BarnacleTheme.monoLabel)
                .foregroundStyle(BarnacleTheme.textPrimary)
        }
    }

    private var isPoweredOn: Bool {
        switch appState {
        case .idle, .error:
            false
        default:
            true
        }
    }

    private var isDisabled: Bool {
        switch appState {
        case .processing, .streaming, .speaking:
            true
        default:
            false
        }
    }
}
