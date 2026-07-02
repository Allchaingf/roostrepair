//
//  ReminderQueueView.swift — Screen 13: Local Reminders
//
//  Account-free local reminders (morning, evening, transport, cleaning, custom).
//  Toggling one schedules/cancels a real UNCalendarNotificationTrigger; Snooze
//  shifts the time. All offline.
//

import SwiftUI

struct ReminderQueueView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var editing: Reminder?
    @State private var showNew = false
    @State private var snoozeTarget: Reminder?
    @State private var toast: Toast?

    var body: some View {
        DetailScaffold(title: "Local Reminders", trailingIcon: "plus", trailingAction: { showNew = true }) {

            if !settings.notificationsEnabled {
                RoostCard {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "bell.slash.fill", tint: Theme.warn)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notifications are off").font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary)
                            Text("Reminders are saved but won't alert until enabled.").font(.roostCaption).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
                PillButton(title: "Enable Notifications", icon: "bell.fill", tint: Theme.amberDeep, filled: true) {
                    NotificationManager.shared.requestAuthorization { granted in
                        if granted {
                            settings.notificationsEnabled = true
                            NotificationManager.shared.resync(store.reminders, enabled: true)
                            toast = Toast(message: "Notifications enabled")
                        } else {
                            toast = Toast(message: "Enable in iOS Settings", symbol: "gear")
                        }
                    }
                }
            }

            if store.reminders.isEmpty {
                RoostCard { EmptyState(symbol: "bell", title: "No reminders",
                                       message: "Add morning, evening, cleaning or transport reminders.") }
            } else {
                ForEach(store.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) { reminder in
                    reminderCard(reminder)
                }
            }

            SecondaryButton(title: "Add Reminder", icon: "plus.circle.fill") { showNew = true }
        }
        .sheet(isPresented: $showNew) {
            ReminderEditorView(reminder: nil) { toast = Toast(message: "Reminder added") }
                .environmentObject(store).environmentObject(settings)
        }
        .sheet(item: $editing) { r in
            ReminderEditorView(reminder: r) { toast = Toast(message: "Reminder saved") }
                .environmentObject(store).environmentObject(settings)
        }
        .actionSheet(item: $snoozeTarget) { reminder in
            ActionSheet(title: Text("Snooze \(reminder.title)"), buttons: [
                .default(Text("10 minutes")) { snooze(reminder, 10) },
                .default(Text("30 minutes")) { snooze(reminder, 30) },
                .default(Text("1 hour")) { snooze(reminder, 60) },
                .cancel()
            ])
        }
        .toast($toast)
    }

    private func reminderCard(_ reminder: Reminder) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: reminder.kind.symbol, tint: reminder.enabled ? Theme.amberDeep : Theme.textFaint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title).font(.roost(15, .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text("\(reminder.kind.title) · \(reminder.timeText)").font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                VStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { reminder.enabled },
                        set: { _ in store.toggleReminder(reminder) }
                    ))
                    .labelsHidden().toggleStyle(SwitchToggleStyle(tint: Theme.amber))
                    HStack(spacing: 6) {
                        Button { snoozeTarget = reminder } label: {
                            Image(systemName: "zzz").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.info)
                                .frame(width: 28, height: 28).background(Circle().fill(Theme.info.opacity(0.15)))
                        }
                        Menu {
                            Button { editing = reminder } label: { Label("Edit", systemImage: "pencil") }
                            Button { store.deleteReminder(reminder) } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 28, height: 28)
                        }
                    }
                }
            }
        }
    }

    private func snooze(_ reminder: Reminder, _ minutes: Int) {
        store.snooze(reminder, minutes: minutes)
        toast = Toast(message: "Snoozed \(minutes) min", symbol: "zzz")
    }
}

// MARK: - Reminder editor

struct ReminderEditorView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) var presentationMode
    var reminder: Reminder?
    var onSave: () -> Void

    @State private var title = ""
    @State private var kind: ReminderKind = .morning
    @State private var time = Date()
    @State private var enabled = true

    var body: some View {
        SheetScaffold(title: reminder == nil ? "Add Reminder" : "Edit Reminder",
                      saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Title", placeholder: "e.g. Morning check", text: $title, icon: "bell.fill")

            Text("TYPE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReminderKind.allCases) { k in
                        SelectChip(text: k.title, symbol: k.symbol, selected: kind == k) {
                            kind = k
                            if title.isEmpty { title = k.title }
                        }
                    }
                }
            }

            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .accentColor(Theme.amberDeep).foregroundColor(Theme.textPrimary)

            Toggle(isOn: $enabled) {
                Text("Enabled").font(.roostBody).foregroundColor(Theme.textPrimary)
            }.toggleStyle(SwitchToggleStyle(tint: Theme.amber))

            if !settings.notificationsEnabled {
                Text("Tip: turn on notifications in Settings so reminders alert you.")
                    .font(.roostCaption).foregroundColor(Theme.textFaint)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let r = reminder else { return }
        title = r.title; kind = r.kind; enabled = r.enabled
        var comps = DateComponents(); comps.hour = r.hour; comps.minute = r.minute
        time = Calendar.current.date(from: comps) ?? Date()
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        if var r = reminder {
            r.title = trimmed; r.kind = kind; r.hour = comps.hour ?? 7; r.minute = comps.minute ?? 0; r.enabled = enabled
            store.updateReminder(r)
        } else {
            store.addReminder(Reminder(title: trimmed, kind: kind, hour: comps.hour ?? 7, minute: comps.minute ?? 0, enabled: enabled))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
