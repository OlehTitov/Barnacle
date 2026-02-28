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

    var body: some View {
        HStack(spacing: blockSpacing) {
            ForEach(0..<blockCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(blockColor(at: index))
                    .frame(width: blockSize, height: blockSize)
            }
        }
    }

    private var litCount: Int {
        guard isRecording else { return 0 }
        let level = max(0, min(1, audioLevel))
        return Int(Float(blockCount) * level)
    }

    private var silenceDrainCount: Int {
        guard isRecording && silenceProgress > 0 else { return 0 }
        let drained = Int(Double(blockCount) * silenceProgress)
        return min(drained, blockCount)
    }

    private func blockColor(at index: Int) -> Color {
        let effectiveLit = max(litCount, blockCount - silenceDrainCount)
        if isRecording && index < effectiveLit {
            return .white
        }
        return Color(white: 0.2)
    }

    private var isRecording: Bool {
        if case .recording = appState { return true }
        return false
    }
}
