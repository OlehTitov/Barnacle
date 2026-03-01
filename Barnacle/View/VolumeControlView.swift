//
//  VolumeControlView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI
import UIKit

struct VolumeControlView: View {

    let appState: AppState

    @State
    private var volume: Int = 7

    @State
    private var minusPressed = false

    @State
    private var plusPressed = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text("\u{2212}")
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundStyle(isPoweredOn ? BarnacleTheme.buttonIconActive : BarnacleTheme.buttonIconInactive)
                    .shadow(color: isPoweredOn ? BarnacleTheme.buttonIconActive.opacity(0.5) : .clear, radius: 4)
                    .frame(width: 44, height: BarnacleTheme.controlButtonSize)
                    .scaleEffect(minusPressed ? 0.92 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: minusPressed)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !minusPressed {
                                    minusPressed = true
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                }
                            }
                            .onEnded { _ in
                                minusPressed = false
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                volume = max(0, volume - 1)
                            }
                    )

                Text("\(volume)")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(isPoweredOn ? BarnacleTheme.buttonIconActive : BarnacleTheme.buttonIconInactive)
                    .shadow(color: isPoweredOn ? BarnacleTheme.buttonIconActive.opacity(0.5) : .clear, radius: 4)
                    .frame(width: 30)

                Text("+")
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundStyle(isPoweredOn ? BarnacleTheme.buttonIconActive : BarnacleTheme.buttonIconInactive)
                    .shadow(color: isPoweredOn ? BarnacleTheme.buttonIconActive.opacity(0.5) : .clear, radius: 4)
                    .frame(width: 44, height: BarnacleTheme.controlButtonSize)
                    .scaleEffect(plusPressed ? 0.92 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: plusPressed)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !plusPressed {
                                    plusPressed = true
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                }
                            }
                            .onEnded { _ in
                                plusPressed = false
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                volume = min(10, volume + 1)
                            }
                    )
            }
            .background(
                ZStack {
                    // 1. Socket — recessed groove
                    Capsule()
                        .fill(BarnacleTheme.buttonSocketInner)
                        .padding(-3)
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.6), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                            .clipShape(Capsule().inset(by: -3))
                        )
                        .overlay(
                            Capsule()
                                .inset(by: -3)
                                .stroke(
                                    LinearGradient(
                                        colors: [.clear, .clear, .white.opacity(0.08)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )

                    // 2. Bezel
                    Capsule()
                        .fill(BarnacleTheme.buttonBase)

                    // 3. Dome with convex lighting
                    Capsule()
                        .fill(
                            EllipticalGradient(
                                colors: [
                                    BarnacleTheme.buttonDomeHighlight,
                                    BarnacleTheme.buttonSurface,
                                    BarnacleTheme.buttonGradientEdge
                                ],
                                center: UnitPoint(x: 0.5, y: 0.6)
                            )
                        )
                        .padding(3)
                        // 4. Rim stroke
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [BarnacleTheme.buttonStrokeTop, BarnacleTheme.buttonStrokeBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                                .padding(3)
                        )
                        .shadow(
                            color: .black.opacity(0.9),
                            radius: 5,
                            x: 0,
                            y: 10
                        )
                }
            )

            Text("VOLUME")
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
