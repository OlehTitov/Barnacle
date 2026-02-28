//
//  SettingsButtonView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct SettingsButtonView: View {

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
                                .stroke(BarnacleTheme.buttonBorder, lineWidth: 2)
                        )

                    Image(systemName: "gearshape")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(BarnacleTheme.textPrimary)
                }
            }

            Text("SETTINGS")
                .font(BarnacleTheme.monoLabel)
                .foregroundStyle(BarnacleTheme.textPrimary)
        }
    }
}
