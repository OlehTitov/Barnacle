//
//  OnboardingFlow.swift
//  Barnacle
//
//  Created by Oleh Titov on 23.02.2026.
//

import SwiftUI

struct OnboardingFlow: View {

    @Environment(AppConfig.self)
    private var config

    @State
    private var currentStep = 0

    var body: some View {
        ZStack {
            BarnacleTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    ConnectStep(onNext: { currentStep = 1 })
                        .tag(0)

                    AuthStep(
                        onNext: { currentStep = 2 },
                        onBack: { currentStep = 0 }
                    )
                    .tag(1)

                    VoiceStep(
                        onDone: {
                            config.isOnboarded = true
                            config.save()
                        },
                        onBack: { currentStep = 1 }
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                index == currentStep
                                    ? BarnacleTheme.accent
                                    : Color.secondary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}
