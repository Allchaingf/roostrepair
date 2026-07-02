//
//  RoostRepairApp.swift
//  RoostRepair
//
//  Entry point. Creates the app-wide @EnvironmentObjects (settings + data store)
//  and shows RootView, which drives Splash -> Onboarding -> Main.
//

import SwiftUI

@main
struct RoostRepairApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = FarmStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .accentColor(Theme.amberDeep)
        }
    }
}
