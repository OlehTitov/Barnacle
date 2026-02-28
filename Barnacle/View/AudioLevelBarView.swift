//
//  AudioLevelBarView.swift
//  Barnacle
//
//  Created by Oleh Titov on 28.02.2026.
//

import SwiftUI

struct AudioLevelBarView: View {

    let audioLevel: Float

    let silenceProgress: Double

    let appState: AppState

    private let blockCount = 30
    private let blockSize: CGFloat = 12
    private let blockSpacing: CGFloat = 3
    private let hotZone = 7

    var body: some View {
        HStack(spacing: blockSpacing) {
            ForEach(0..<blockCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(blockColor(at: index))
                    .frame(height: blockSize)
            }
        }
    }

    private var litCount: Int {
        guard isActive else { return 0 }
        let level = max(0, min(1, audioLevel))
        return Int(Float(blockCount) * level)
    }

    private func blockColor(at index: Int) -> Color {
        guard isActive else {
            return Color(white: 0.2)
        }

        let lit: Int
        if silenceProgress > 0 {
            lit = blockCount - Int(Double(blockCount) * min(silenceProgress, 1))
        } else {
            lit = litCount
        }

        guard index < lit else {
            return Color(white: 0.2)
        }

        if index >= blockCount - hotZone {
            let hotIndex = index - (blockCount - hotZone)
            let t = Double(hotIndex) / Double(hotZone - 1)
            return Color(red: 1.0, green: 0.45 - t * 0.35, blue: 0.1)
        }

        return .white
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
