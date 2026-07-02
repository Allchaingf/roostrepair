//
//  AppSettings.swift
//  RoostRepair
//
//  App-wide preferences (theme, units, notifications, accent labels, onboarding,
//  farm board view mode, care priorities). Injected as an @EnvironmentObject so
//  any screen can read/write it and changes apply instantly across the app.
//

import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.fill"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum MeasureSystem: String, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var areaUnit: String { self == .metric ? "m²" : "ft²" }
    var lengthUnit: String { self == .metric ? "cm" : "in" }
    var weightUnit: String { self == .metric ? "kg" : "lb" }
}

final class AppSettings: ObservableObject {

    // Keys
    private enum K {
        static let theme = "set.theme"
        static let measure = "set.measure"
        static let notifications = "set.notifications"
        static let amberLabels = "set.amberLabels"
        static let onboarded = "hasCompletedOnboarding"
        static let viewMode = "set.viewMode"
        static let priorities = "set.priorities"
        static let currency = "set.currency"
    }

    @Published var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: K.theme) }
    }
    @Published var measureSystem: MeasureSystem {
        didSet { UserDefaults.standard.set(measureSystem.rawValue, forKey: K.measure) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: K.notifications) }
    }
    /// Show warm amber colour markers on cards (vs. neutral).
    @Published var amberIndicators: Bool {
        didSet { UserDefaults.standard.set(amberIndicators, forKey: K.amberLabels) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: K.onboarded) }
    }
    @Published var viewMode: FarmViewMode {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: K.viewMode) }
    }
    @Published var priorities: Set<CarePriority> {
        didSet {
            let raw = priorities.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: K.priorities)
        }
    }
    @Published var currencySymbol: String {
        didSet { UserDefaults.standard.set(currencySymbol, forKey: K.currency) }
    }

    init() {
        let d = UserDefaults.standard
        themeMode = ThemeMode(rawValue: d.string(forKey: K.theme) ?? "") ?? .system
        measureSystem = MeasureSystem(rawValue: d.string(forKey: K.measure) ?? "") ?? .metric
        notificationsEnabled = d.object(forKey: K.notifications) as? Bool ?? false
        amberIndicators = d.object(forKey: K.amberLabels) as? Bool ?? true
        hasCompletedOnboarding = d.bool(forKey: K.onboarded)
        viewMode = FarmViewMode(rawValue: d.string(forKey: K.viewMode) ?? "") ?? .coopMap
        let rawPriorities = d.stringArray(forKey: K.priorities) ?? ["health", "feed"]
        priorities = Set(rawPriorities.compactMap { CarePriority(rawValue: $0) })
        currencySymbol = d.string(forKey: K.currency) ?? "$"
    }

    func resetPreferences() {
        themeMode = .system
        measureSystem = .metric
        notificationsEnabled = false
        amberIndicators = true
        viewMode = .coopMap
        priorities = [.health, .feed]
        currencySymbol = "$"
    }
}
