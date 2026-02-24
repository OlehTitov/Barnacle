//
//  BarnacleShortcuts.swift
//  Barnacle
//
//  Created by Oleh Titov on 24.02.2026.
//

import AppIntents

struct BarnacleShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BarnacleIntent(),
            phrases: [
                "Open \(.applicationName)",
                "\(.applicationName)",
                "Talk to \(.applicationName)",
                "Hey \(.applicationName)"
            ],
            shortTitle: "Barnacle",
            systemImageName: "waveform"
        )
    }
}
