//
//  RootView.swift
//  RoostRepair
//
//  Coordinates the strict entry flow: Splash -> (first launch) Onboarding -> Main.
//  Applies the chosen colour scheme app-wide so theme changes repaint instantly.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: FarmStore
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                LaunchView {
                    withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                }
                .transition(.opacity)
            } else if !settings.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(settings.themeMode.colorScheme)
    }
}
