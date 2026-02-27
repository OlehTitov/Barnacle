//
//  ModelDownloadView.swift
//  Barnacle
//
//  Created by Oleh Titov on 25.02.2026.
//

import SwiftUI

struct ModelDownloadView: View {

    let isPreparing: Bool

    let errorMessage: String?

    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if isPreparing {
                ProgressView()
                    .controlSize(.large)
                    .tint(BarnacleTheme.coral)

                Text("Preparing speech engine")
                    .font(BarnacleTheme.monoBody)
                    .foregroundStyle(.white)
            } else if let errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(BarnacleTheme.coral)

                Text("Model download failed")
                    .font(BarnacleTheme.monoBody)
                    .foregroundStyle(.white)

                Text(errorMessage)
                    .font(BarnacleTheme.monoCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Retry", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(BarnacleTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BarnacleTheme.background.ignoresSafeArea())
    }
}
