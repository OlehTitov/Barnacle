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

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(BarnacleTheme.buttonSurface)
                        .frame(
                            width: BarnacleTheme.controlButtonSize,
                            height: BarnacleTheme.controlButtonSize
                        )
                        .overlay(
                            Circle()
                                .stroke(isActive ? BarnacleTheme.accent : BarnacleTheme.buttonBorder, lineWidth: 2)
                        )
                        .shadow(color: isActive ? BarnacleTheme.accent.opacity(0.4) : .clear, radius: 8)

                    Image(systemName: "power")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isActive ? BarnacleTheme.accent : BarnacleTheme.textPrimary)
                }
            }
            .disabled(isDisabled)

            Text("POWER")
                .font(BarnacleTheme.monoLabel)
                .foregroundStyle(BarnacleTheme.textPrimary)
        }
    }

    private var isActive: Bool {
        switch appState {
        case .recording:
            true
        default:
            false
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
