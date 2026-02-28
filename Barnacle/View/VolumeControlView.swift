//
//  VolumeControlView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct VolumeControlView: View {

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
                        .foregroundStyle(BarnacleTheme.textPrimary)
                        .frame(width: 44, height: BarnacleTheme.controlButtonSize)
                }

                Text("\(volume)")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(BarnacleTheme.textPrimary)
                    .frame(width: 30)

                Button {
                    volume = min(10, volume + 1)
                } label: {
                    Text("+")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(BarnacleTheme.textPrimary)
                        .frame(width: 44, height: BarnacleTheme.controlButtonSize)
                }
            }
            .background(
                Capsule()
                    .fill(BarnacleTheme.buttonSurface)
                    .overlay(
                        Capsule()
                            .stroke(BarnacleTheme.buttonBorder, lineWidth: 2)
                    )
            )

            Text("VOLUME")
                .font(BarnacleTheme.monoLabel)
                .foregroundStyle(BarnacleTheme.textPrimary)
        }
    }
}
