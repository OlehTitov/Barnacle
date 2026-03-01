//
//  BarnacleApp.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

@main
struct BarnacleApp: App {

    @State
    private var config = AppConfig()

    var body: some Scene {
        let _ = (BarnacleTheme.current = config.visualTheme)
        WindowGroup {
            Group {
                if config.isOnboarded {
                    MainView()
                } else {
                    OnboardingFlow()
                }
            }
            .tint(BarnacleTheme.accent)
            .preferredColorScheme(config.visualTheme.colorScheme)
            .id(config.visualTheme)
        }
        .environment(config)
    }
}
