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
        WindowGroup {
            if config.isOnboarded {
                MainView()
            } else {
                OnboardingFlow()
            }
        }
        .environment(config)
    }
}
