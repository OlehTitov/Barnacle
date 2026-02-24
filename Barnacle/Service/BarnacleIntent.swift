//
//  BarnacleIntent.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import AppIntents
import Foundation

struct BarnacleIntent: AppIntent {

    static let title: LocalizedStringResource = "Talk to Barnacle"

    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let config = AppConfig()

        guard !config.gatewayURL.isEmpty, !config.gatewayToken.isEmpty else {
            throw IntentError.missingCredentials
        }

        NotificationCenter.default.post(name: .barnacleIntentTriggered, object: nil)

        return .result()
    }
}

extension Notification.Name {

    static let barnacleIntentTriggered = Notification.Name("barnacleIntentTriggered")
}
