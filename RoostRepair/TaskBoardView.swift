//
//  TaskBoardView.swift — Screen 12: Farm Tasks
//
//  Priority task board for repairs, purchases, cleaning and checks. Filter by
//  priority, toggle done, full create/edit/delete via the editor sheet.
//

import SwiftUI

struct TaskBoardView: View {
    @EnvironmentObject var store: FarmStore
    @State private var filter: TaskPriority?
    @State private var showFilter = false
    @State private var editing: FarmTask?
    @State private var showNew = false
    @State private var toast: Toast?

    private var visible: [FarmTask] {
        let base = store.tasks.sorted { lhs, rhs in
            if lhs.done != rhs.done { return !lhs.done }
            if lhs.priority.rank != rhs.priority.rank { return lhs.priority.rank < rhs.priority.rank }
            return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
        }
        guard let f = filter else { return base }
        return base.filter { $0.priority == f }
    }

    var body: some View {
        DetailScaffold(title: "Farm Tasks", trailingIcon: "plus", trailingAction: { showNew = true }) {
            HStack(spacing: 12) {
                StatTile(value: "\(store.openTasks.count)", label: "Open", symbol: "tray.full.fill")
                StatTile(value: "\(store.tasks.filter { $0.isOverdue }.count)", label: "Overdue", symbol: "exclamationmark.triangle.fill", tint: Theme.danger)
                StatTile(value: "\(store.tasks.filter { $0.done }.count)", label: "Done", symbol: "checkmark.seal.fill", tint: Theme.ok)
            }

            HStack(spacing: 8) {
                PillButton(title: "Set Priority", icon: "slider.horizontal.3", filled: showFilter) {
                    withAnimation(Metric.spring) { showFilter.toggle() }
                }
                Spacer()
                PillButton(title: "New Task", icon: "plus", tint: Theme.amberDeep, filled: true) { showNew = true }
            }

            if showFilter {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SelectChip(text: "All", selected: filter == nil) { filter = nil }
                        ForEach(TaskPriority.allCases) { p in
                            SelectChip(text: p.title, selected: filter == p, tint: p.tint) {
                                filter = filter == p ? nil : p
                            }
                        }
                    }
                }
            }

            if visible.isEmpty {
                RoostCard { EmptyState(symbol: "checkmark.square", title: "No tasks",
                                       message: "Add repairs, purchases and checks to your board.") }
            } else {
                ForEach(visible) { task in taskCard(task) }
            }
        }
        .sheet(isPresented: $showNew) {
            TaskEditorView(task: nil) { toast = Toast(message: "Task added") }.environmentObject(store)
        }
        .sheet(item: $editing) { t in
            TaskEditorView(task: t) { toast = Toast(message: "Task saved") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func taskCard(_ task: FarmTask) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 12) {
                Button { withAnimation(Metric.spring) { store.toggleTask(task) } } label: {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24)).foregroundColor(task.done ? Theme.ok : Theme.stroke)
                }.buttonStyle(PressableStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.roost(15, .semibold))
                        .foregroundColor(task.done ? Theme.textFaint : Theme.textPrimary)
                        .strikethrough(task.done, color: Theme.textFaint).lineLimit(1)
                    HStack(spacing: 6) {
                        TagChip(text: task.priority.title, tint: task.priority.tint)
                        if task.zoneID != nil { TagChip(text: store.zoneName(task.zoneID), symbol: "mappin", tint: Theme.wood) }
                        if let due = task.dueDate {
                            TagChip(text: FarmStore.shortDate(due), symbol: "calendar",
                                    tint: task.isOverdue ? Theme.danger : Theme.textSecondary)
                        }
                    }
                }
                Spacer()
                Menu {
                    Button { editing = task } label: { Label("Edit", systemImage: "pencil") }
                    Button { store.deleteTask(task) } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 30, height: 30)
                }
            }
        }
    }
}

// MARK: - Task editor

struct TaskEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var task: FarmTask?
    var onSave: () -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var priority: TaskPriority = .medium
    @State private var zoneID: UUID?
    @State private var hasDue = true
    @State private var due = Date()

    var body: some View {
        SheetScaffold(title: task == nil ? "New Task" : "Edit Task",
                      saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Task", placeholder: "e.g. Fix run door latch", text: $title, icon: "wrench.and.screwdriver.fill")

            VStack(alignment: .leading, spacing: 6) {
                Text("DETAILS").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                TextEditor(text: $detail).frame(height: 70).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }

            Text("PRIORITY").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases) { p in
                    SelectChip(text: p.title, symbol: "flag.fill", selected: priority == p, tint: p.tint) { priority = p }
                }
            }

            Text("ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }

            Toggle(isOn: $hasDue) {
                Text("Set due date").font(.roostBody).foregroundColor(Theme.textPrimary)
            }.toggleStyle(SwitchToggleStyle(tint: Theme.amber))
            if hasDue {
                DatePicker("Due", selection: $due, displayedComponents: .date)
                    .accentColor(Theme.amberDeep).foregroundColor(Theme.textPrimary)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let t = task else { return }
        title = t.title; detail = t.detail; priority = t.priority; zoneID = t.zoneID
        if let d = t.dueDate { hasDue = true; due = d } else { hasDue = false }
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var t = task {
            t.title = trimmed; t.detail = detail; t.priority = priority
            t.zoneID = zoneID; t.dueDate = hasDue ? due : nil
            store.updateTask(t)
        } else {
            store.addTask(FarmTask(title: trimmed, detail: detail, priority: priority,
                                   zoneID: zoneID, dueDate: hasDue ? due : nil))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
