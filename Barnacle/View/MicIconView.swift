//
//  MicIconView.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct MicIconView: View {

    let appState: AppState

    var body: some View {
        switch appState {
        case .processing:
            ProgressView()
                .tint(.white)
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
        default:
            Image(systemName: "mic.fill")
        }
    }
}
