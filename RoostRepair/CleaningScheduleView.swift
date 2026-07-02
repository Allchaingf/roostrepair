//
//  CleaningScheduleView.swift — Screen 7: Clean Plan
//
//  Schedule cleaning, bedding changes and sanitation cycles per zone. Marking a
//  task clean logs a record and rolls the due date forward by its interval.
//  Overdue tasks surface on the Dashboard as risk flags.
//

import SwiftUI

struct CleaningScheduleView: View {
    @EnvironmentObject var store: FarmStore
    @State private var editing: CleaningTask?
    @State private var showNew = false
    @State private var toast: Toast?

    private var sorted: [CleaningTask] {
        store.cleaningTasks.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        DetailScaffold(title: "Clean Plan", trailingIcon: "plus", trailingAction: { showNew = true }) {
            HStack(spacing: 12) {
                StatTile(value: "\(store.cleaningTasks.count)", label: "Scheduled", symbol: "sparkles")
                StatTile(value: "\(store.overdueCleaning.count)", label: "Overdue", symbol: "exclamationmark.triangle.fill",
                         tint: store.overdueCleaning.isEmpty ? Theme.ok : Theme.danger)
            }

            SecondaryButton(title: "Schedule Task", icon: "calendar.badge.plus") { showNew = true }

            if sorted.isEmpty {
                RoostCard { EmptyState(symbol: "sparkles", title: "Nothing scheduled",
                                       message: "Plan deep cleans, bedding swaps and sanitation.") }
            } else {
                ForEach(sorted) { task in cleaningCard(task) }
            }
        }
        .sheet(isPresented: $showNew) {
            CleaningEditorView(task: nil) { toast = Toast(message: "Task scheduled") }.environmentObject(store)
        }
        .sheet(item: $editing) { t in
            CleaningEditorView(task: t) { toast = Toast(message: "Task saved") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func cleaningCard(_ task: CleaningTask) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: "sparkles", tint: task.isOverdue ? Theme.danger : Color(hex: 0x6FA45C))
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.roost(15, .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    HStack(spacing: 6) {
                        TagChip(text: store.zoneName(task.zoneID), symbol: "mappin", tint: Theme.wood)
                        TagChip(text: "Every \(task.intervalDays)d", symbol: "repeat", tint: Theme.info)
                    }
                    Text(task.isOverdue ? "Overdue · due \(FarmStore.shortDate(task.dueDate))" : "Due \(FarmStore.shortDate(task.dueDate))")
                        .font(.roost(11, .semibold)).foregroundColor(task.isOverdue ? Theme.danger : Theme.textSecondary)
                }
                Spacer()
                VStack(spacing: 8) {
                    Button { mark(task) } label: {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(width: 34, height: 34).background(Circle().fill(Theme.ok))
                    }.buttonStyle(PressableStyle())
                    Menu {
                        Button { editing = task } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.deleteCleaning(task) } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 28, height: 28)
                    }
                }
            }
        }
    }

    private func mark(_ task: CleaningTask) {
        withAnimation(Metric.spring) { store.markCleaned(task) }
        toast = Toast(message: "Marked clean · next in \(task.intervalDays)d")
    }
}

// MARK: - Cleaning editor

struct CleaningEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var task: CleaningTask?
    var onSave: () -> Void

    @State private var title = ""
    @State private var zoneID: UUID?
    @State private var due = Date()
    @State private var interval = 7

    var body: some View {
        SheetScaffold(title: task == nil ? "Schedule Task" : "Edit Task",
                      saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Task", placeholder: "e.g. Deep clean coop", text: $title, icon: "sparkles")

            Text("ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }

            DatePicker("Next due", selection: $due, displayedComponents: .date)
                .accentColor(Theme.amberDeep).foregroundColor(Theme.textPrimary)

            RoostStepper(title: "Repeat every (days)", value: $interval, range: 1...90)
        }
        .onAppear {
            if let t = task { title = t.title; zoneID = t.zoneID; due = t.dueDate; interval = t.intervalDays }
        }
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var t = task {
            t.title = trimmed; t.zoneID = zoneID; t.dueDate = due; t.intervalDays = interval
            store.updateCleaning(t)
        } else {
            store.addCleaning(CleaningTask(title: trimmed, zoneID: zoneID, dueDate: due, intervalDays: interval))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
