//
//  SettingsView.swift — Screen 24: App Preferences
//
//  App-only preferences (no account). Every control has a real, visible effect:
//  theme repaints the app, units change calculators, the notifications toggle
//  drives UNUserNotificationCenter, and sample data can be reset.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: FarmStore

    @State private var showResetData = false
    @State private var showResetPrefs = false
    @State private var notifDeniedAlert = false
    @State private var toast: Toast?

    private let currencies = ["$", "€", "£", "₽", "¥", "₴", "zł"]

    var body: some View {
        DetailScaffold(title: "App Preferences") {

            // Appearance
            sectionCard(title: "Appearance", symbol: "paintpalette.fill") {
                rowLabel("Theme")
                HStack(spacing: 10) {
                    ForEach(ThemeMode.allCases) { mode in
                        Button { withAnimation(Metric.spring) { settings.themeMode = mode } } label: {
                            VStack(spacing: 6) {
                                Image(systemName: mode.symbol).font(.system(size: 18, weight: .semibold))
                                Text(mode.title).font(.roost(12, .semibold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundColor(settings.themeMode == mode ? .white : Theme.textSecondary)
                            .background(RoundedRectangle(cornerRadius: Metric.radiusSmall)
                                .fill(settings.themeMode == mode ? Theme.amberGradient : Theme.background.asGradient))
                            .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall)
                                .stroke(Theme.stroke, lineWidth: settings.themeMode == mode ? 0 : 1))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                Divider().background(Theme.stroke).padding(.vertical, 4)
                Toggle(isOn: $settings.amberIndicators) {
                    Label("Amber colour markers", systemImage: "circle.grid.3x3.fill")
                        .font(.roostBody).foregroundColor(Theme.textPrimary)
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.amber))
            }

            // Units
            sectionCard(title: "Units & Currency", symbol: "ruler.fill") {
                rowLabel("Measurement")
                HStack(spacing: 10) {
                    ForEach(MeasureSystem.allCases) { sys in
                        SelectChip(text: "\(sys.title) (\(sys.areaUnit))", selected: settings.measureSystem == sys) {
                            settings.measureSystem = sys
                            toast = Toast(message: "Units: \(sys.title)", symbol: "ruler.fill")
                        }
                    }
                    Spacer()
                }
                Divider().background(Theme.stroke).padding(.vertical, 4)
                rowLabel("Currency")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currencies, id: \.self) { c in
                            SelectChip(text: c, selected: settings.currencySymbol == c) { settings.currencySymbol = c }
                        }
                    }
                }
            }

            // Notifications
            sectionCard(title: "Local Notifications", symbol: "bell.badge.fill") {
                Toggle(isOn: $settings.notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable reminders").font(.roostBody).foregroundColor(Theme.textPrimary)
                        Text("Schedules your local reminder queue").font(.roostCaption).foregroundColor(Theme.textSecondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.amber))
                .onChange(of: settings.notificationsEnabled) { enabled in
                    if enabled {
                        NotificationManager.shared.requestAuthorization { granted in
                            if granted {
                                NotificationManager.shared.resync(store.reminders, enabled: true)
                                toast = Toast(message: "Reminders scheduled", symbol: "bell.fill")
                            } else {
                                settings.notificationsEnabled = false
                                notifDeniedAlert = true
                            }
                        }
                    } else {
                        NotificationManager.shared.cancelAll()
                        toast = Toast(message: "Reminders paused", symbol: "bell.slash.fill")
                    }
                }
                if settings.notificationsEnabled {
                    NavigationLink(destination: ReminderQueueView()) {
                        HStack {
                            Text("Manage reminder queue").font(.roost(14, .semibold)).foregroundColor(Theme.amberDeep)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(Theme.textFaint).font(.system(size: 12, weight: .bold))
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Data
            sectionCard(title: "Data", symbol: "tray.full.fill") {
                dataStat
                Button { showResetData = true } label: {
                    settingsButtonLabel("Reset Sample Data", symbol: "arrow.counterclockwise", tint: Theme.rust)
                }.buttonStyle(PressableStyle())
                Button { showResetPrefs = true } label: {
                    settingsButtonLabel("Reset Preferences", symbol: "slider.horizontal.3", tint: Theme.textSecondary)
                }.buttonStyle(PressableStyle())
            }

            // About
            sectionCard(title: "About", symbol: "info.circle.fill") {
                aboutRow("Version", "1.0")
                aboutRow("Mode", "Offline · on-device")
                aboutRow("Account", "None — no sign-in")
                Text("Roost Repair keeps every record on your device. No profile, no cloud, no sign-in.")
                    .font(.roostCaption).foregroundColor(Theme.textSecondary).padding(.top, 4)
            }
        }
        .alert(isPresented: $showResetData) {
            Alert(title: Text("Reset Sample Data?"),
                  message: Text("This clears your records and restores the starter farm. This cannot be undone."),
                  primaryButton: .destructive(Text("Reset")) {
                    store.resetSampleData()
                    if settings.notificationsEnabled {
                        NotificationManager.shared.resync(store.reminders, enabled: true)
                    }
                    toast = Toast(message: "Sample data restored", symbol: "checkmark.circle.fill")
                  },
                  secondaryButton: .cancel())
        }
        .alert(isPresented: $showResetPrefs) {
            Alert(title: Text("Reset Preferences?"),
                  message: Text("Theme, units, currency and priorities return to defaults."),
                  primaryButton: .destructive(Text("Reset")) {
                    settings.resetPreferences()
                    toast = Toast(message: "Preferences reset")
                  },
                  secondaryButton: .cancel())
        }
        .alert(isPresented: $notifDeniedAlert) {
            Alert(title: Text("Notifications Off"),
                  message: Text("Enable notifications for Roost Repair in the iOS Settings app to schedule reminders."),
                  dismissButton: .default(Text("OK")))
        }
        .toast($toast)
    }

    // MARK: helpers
    private func sectionCard<C: View>(title: String, symbol: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(symbol: symbol, tint: Theme.amberDeep, size: 34)
                Text(title).font(.roost(17, .bold)).foregroundColor(Theme.textPrimary)
            }
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(Theme.stroke, lineWidth: 1))
    }

    private func rowLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsButtonLabel(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundColor(tint)
            Text(title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(Theme.textFaint).font(.system(size: 12, weight: .bold))
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
    }

    private func aboutRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.roostBody).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary)
        }
    }

    private var dataStat: some View {
        HStack(spacing: 10) {
            dataPill("\(store.groups.count)", "groups")
            dataPill("\(store.logs.count)", "records")
            dataPill("\(store.tasks.count)", "tasks")
            dataPill("\(store.inventory.count)", "items")
        }
    }
    private func dataPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.roost(18, .bold)).foregroundColor(Theme.amberDeep)
            Text(label).font(.roost(10, .medium)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
    }
}
