//
//  PowerButtonView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI
import UIKit

struct PowerButtonView: View {

    let appState: AppState

    let action: () -> Void

    @State
    private var isPressed = false

    private let size = BarnacleTheme.controlButtonSize

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 1. Socket — recessed groove
                Circle()
                    .fill(BarnacleTheme.buttonSocketInner)
                    .frame(width: size + 6, height: size + 6)
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
                    .frame(width: size, height: size)

                // 3. Button dome with convex lighting
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BarnacleTheme.buttonDomeHighlight,
                                BarnacleTheme.buttonSurface,
                                BarnacleTheme.buttonGradientEdge
                            ],
                            center: isPressed ? UnitPoint(x: 0.5, y: 0.38) : UnitPoint(x: 0.5, y: 0.6),
                            startRadius: 0,
                            endRadius: (size - 6) / 2.2
                        )
                    )
                    .frame(width: size - 6, height: size - 6)
                    // 4. Rim stroke
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
                    .shadow(
                        color: isPoweredOn ? .clear : .black.opacity(0.9),
                        radius: isPoweredOn ? 0 : 5,
                        x: 0,
                        y: isPoweredOn ? 0 : 10
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: isPressed)

                // 5. Icon
                Image(systemName: "power")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isPoweredOn ? BarnacleTheme.buttonIconActive : BarnacleTheme.buttonIconInactive)
                    .shadow(color: isPoweredOn ? BarnacleTheme.buttonIconActive.opacity(0.5) : .clear, radius: 4)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: isPressed)
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
}
