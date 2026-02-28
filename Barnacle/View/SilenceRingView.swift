//
//  SilenceRingView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct SilenceRingView: View {

    let progress: Double

    var body: some View {
        Circle()
            .trim(from: 0, to: 1 - progress)
            .stroke(
                BarnacleTheme.accent.opacity(0.6),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 0.1), value: progress)
    }
}
