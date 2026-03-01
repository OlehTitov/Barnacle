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
                Capsule()
                    .fill(BarnacleTheme.buttonBase)
                    .overlay(
                        Capsule()
                            .fill(
                                EllipticalGradient(
                                    colors: [BarnacleTheme.buttonSurface, BarnacleTheme.buttonGradientEdge],
                                    center: .center
                                )
                            )
                            .padding(3)
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
                    )
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
