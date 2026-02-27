//
//  FluidModelService.swift
//  Barnacle
//
//  Created by Oleh Titov on 25.02.2026.
//

import FluidAudio
import Foundation

@Observable
final class FluidModelService {

    private(set) var isReady = false

    private(set) var isPreparing = false

    private(set) var errorMessage: String?

    func prepareIfNeeded(using conversation: ConversationService) async {
        guard !isReady, !isPreparing else { return }
        isPreparing = true
        errorMessage = nil

        do {
            try await conversation.prepareFluidModels()
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isPreparing = false
    }
}
