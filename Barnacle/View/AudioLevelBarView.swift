//
//  AudioLevelBarView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import Combine
import SwiftUI

struct AudioLevelBarView: View {

    let audioLevel: Float

    let silenceProgress: Double

    let appState: AppState

    @State
    private var displayedLit = 0

    private let blockCount = 30
    private let blockSize: CGFloat = 12
    private let blockSpacing: CGFloat = 3
    private let hotZone = 7
    private let stepTimer = Timer.publish(every: 0.015, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: blockSpacing) {
            ForEach(0..<blockCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(blockColor(at: index))
                    .frame(height: blockSize)
            }
        }
        .onReceive(stepTimer) { _ in
            let target = targetLit
            if displayedLit < target {
                displayedLit += 1
            } else if displayedLit > target {
                displayedLit -= 1
            }
        }
    }

    private var targetLit: Int {
        guard isActive else { return 0 }
        if silenceProgress > 0 {
            return blockCount - Int(Double(blockCount) * min(silenceProgress, 1))
        }
        let level = max(0, min(1, audioLevel))
        return Int(Float(blockCount) * level)
    }

    private func blockColor(at index: Int) -> Color {
        guard isActive || displayedLit > 0 else {
            return BarnacleTheme.audioBlockInactive
        }

        guard index < displayedLit else {
            return BarnacleTheme.audioBlockInactive
        }

        if index >= blockCount - hotZone {
            let hotIndex = index - (blockCount - hotZone)
            let t = Double(hotIndex) / Double(hotZone - 1)
            return Color(red: 1.0, green: 0.45 - t * 0.35, blue: 0.1)
        }

        return BarnacleTheme.audioBlockActive
    }

    private var isActive: Bool {
        switch appState {
        case .idle:
            false
        default:
            true
        }
    }
}
