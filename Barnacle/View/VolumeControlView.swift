//
//  VolumeControlView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct VolumeControlView: View {

    let appState: AppState

    @State
    private var volume: Int = 7

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Button {
                    volume = max(0, volume - 1)
                } label: {
                    Text("\u{2212}")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(isPoweredOn ? .white : Color(white: 0.4))
                        .shadow(color: isPoweredOn ? .white.opacity(0.5) : .clear, radius: 4)
                        .frame(width: 44, height: BarnacleTheme.controlButtonSize)
                }

                Text("\(volume)")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(isPoweredOn ? .white : Color(white: 0.4))
                    .shadow(color: isPoweredOn ? .white.opacity(0.5) : .clear, radius: 4)
                    .frame(width: 30)

                Button {
                    volume = min(10, volume + 1)
                } label: {
                    Text("+")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(isPoweredOn ? .white : Color(white: 0.4))
                        .shadow(color: isPoweredOn ? .white.opacity(0.5) : .clear, radius: 4)
                        .frame(width: 44, height: BarnacleTheme.controlButtonSize)
                }
            }
            .background(
                Capsule()
                    .fill(Color.black)
                    .overlay(
                        Capsule()
                            .fill(
                                EllipticalGradient(
                                    colors: [BarnacleTheme.buttonSurface, Color(red: 0.08, green: 0.09, blue: 0.11)],
                                    center: .center
                                )
                            )
                            .padding(3)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(white: 0.35), Color(white: 0.08)],
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
