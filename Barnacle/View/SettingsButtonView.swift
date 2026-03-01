//
//  SettingsButtonView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI
import UIKit

struct SettingsButtonView: View {

    let appState: AppState

    let action: () -> Void

    @State
    private var isPressed = false

    private let size = BarnacleTheme.controlButtonSize

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(BarnacleTheme.buttonBase)
                    .frame(width: size, height: size)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [BarnacleTheme.buttonSurface, BarnacleTheme.buttonGradientEdge],
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
                                    colors: [BarnacleTheme.buttonStrokeTop, BarnacleTheme.buttonStrokeBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )

                Image(systemName: "gearshape")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isPoweredOn ? BarnacleTheme.buttonIconActive : BarnacleTheme.buttonIconInactive)
                    .shadow(color: isPoweredOn ? BarnacleTheme.buttonIconActive.opacity(0.5) : .clear, radius: 4)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        action()
                    }
            )

            Text("SETTINGS")
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
}
