//
//  SpeakingWaveView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct SpeakingWaveView: View {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private let barCount = 5

    var body: some View {
        if reduceMotion {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.white)
        } else {
            TimelineView(.animation) { timeline in
                HStack(spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
                            .frame(
                                width: 4,
                                height: barHeight(
                                    for: index,
                                    phase: timeline.date.timeIntervalSinceReferenceDate
                                )
                            )
                    }
                }
            }
        }
    }

    private func barHeight(for index: Int, phase: Double) -> CGFloat {
        let offset = Double(index) * 0.8
        let sine = sin(phase * 4 + offset)
        return CGFloat(12 + sine * 10)
    }
}
