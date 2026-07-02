//
//  DailyReviewView.swift — Screen 17: End of Day Review
//
//  Evening check that reconciles what was closed vs missed today, lets you add
//  missing records, and completes the day with a saved summary.
//

import SwiftUI

struct DailyReviewView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var showQuickAdd = false
    @State private var toast: Toast?

    private var checklistDone: Int { store.checklist().items.values.filter { $0 }.count }
    private var checklistTotal: Int { DailyChecklistCatalog.items.count }
    private var logsToday: Int { store.logsToday.count }
    private var tasksDueToday: [FarmTask] {
        store.tasks.filter { t in
            guard let d = t.dueDate, !t.done else { return false }
            return Calendar.current.isDateInToday(d) || t.isOverdue
        }
    }
    private var fedToday: Bool { store.logsToday.contains { $0.kind == .feeding } }
    private var wateredToday: Bool { store.logsToday.contains { $0.kind == .water } }

    var body: some View {
        DetailScaffold(title: "End of Day Review") {
            RoostCard {
                HStack(spacing: 18) {
                    ProgressRing(progress: store.checklistProgress(total: checklistTotal), size: 76, lineWidth: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateText).font(.roost(16, .bold)).foregroundColor(Theme.textPrimary)
                        Text("\(checklistDone)/\(checklistTotal) checks · \(logsToday) records")
                            .font(.roostCaption).foregroundColor(Theme.textSecondary)
                        Text("\(tasksDueToday.count) task(s) still open")
                            .font(.roost(12, .semibold)).foregroundColor(tasksDueToday.isEmpty ? Theme.ok : Theme.warn)
                    }
                    Spacer()
                }
            }

            SectionHeader(title: "Today's Care")
            RoostCard {
                VStack(spacing: 12) {
                    reviewRow("Fed the flock", done: fedToday, symbol: "bag.fill")
                    Divider().background(Theme.stroke)
                    reviewRow("Water checked", done: wateredToday, symbol: "drop.fill")
                    Divider().background(Theme.stroke)
                    reviewRow("Checklist complete", done: checklistDone == checklistTotal, symbol: "list.bullet")
                    Divider().background(Theme.stroke)
                    reviewRow("No urgent flags", done: store.riskFlags.filter { $0.severity == .high }.isEmpty, symbol: "flag.fill")
                }
            }

            if !tasksDueToday.isEmpty {
                SectionHeader(title: "Still Open Today")
                ForEach(tasksDueToday.prefix(5)) { task in
                    RoostCard(padding: 12) {
                        HStack(spacing: 12) {
                            Button { withAnimation(Metric.spring) { store.toggleTask(task) } } label: {
                                Image(systemName: "circle").font(.system(size: 22)).foregroundColor(Theme.stroke)
                            }.buttonStyle(PressableStyle())
                            Text(task.title).font(.roost(14, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                            Spacer()
                            TagChip(text: task.priority.title, tint: task.priority.tint)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Complete Day", icon: "moon.stars.fill") { completeDay() }
                SecondaryButton(title: "Add Missing", icon: "plus") { showQuickAdd = true }
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView().environmentObject(store).environmentObject(settings)
        }
        .toast($toast)
    }

    private var dateText: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM"; return f.string(from: Date())
    }

    private func reviewRow(_ title: String, done: Bool, symbol: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: done ? Theme.ok : Theme.textFaint, size: 34)
            Text(title).font(.roostBody).foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? Theme.ok : Theme.stroke).font(.system(size: 22))
        }
    }

    private func completeDay() {
        let detail = "\(checklistDone)/\(checklistTotal) checks · \(logsToday) records · \(tasksDueToday.count) open"
        store.log(CareLog(kind: .note, title: "Day reviewed", detail: detail))
        toast = Toast(message: "Day completed & saved", symbol: "moon.stars.fill")
    }
}
