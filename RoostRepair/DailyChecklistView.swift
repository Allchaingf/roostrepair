//
//  DailyChecklistView.swift — Screen 3: Morning / Evening Checks
//
//  Per-day checklist of feeding, water, doors, bedding and observation. Closed
//  items raise the weekly consistency score used across the app.
//

import SwiftUI

struct DailyChecklistView: View {
    @EnvironmentObject var store: FarmStore
    @State private var refresh = false   // forces recompute after toggles
    @State private var toast: Toast?

    private var day: ChecklistDay { store.checklist() }
    private var progress: Double { store.checklistProgress(total: DailyChecklistCatalog.items.count) }

    var body: some View {
        DetailScaffold(title: "Daily Checklist") {
            RoostCard {
                HStack(spacing: 18) {
                    ProgressRing(progress: progress, size: 76, lineWidth: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(progressTitle).font(.roost(18, .bold)).foregroundColor(Theme.textPrimary)
                        Text("\(doneCount)/\(DailyChecklistCatalog.items.count) checks complete today")
                            .font(.roostCaption).foregroundColor(Theme.textSecondary)
                        Text("Week consistency \(Int(store.weeklyConsistency * 100))%")
                            .font(.roost(12, .semibold)).foregroundColor(Theme.amberDeep)
                    }
                    Spacer()
                }
            }

            section("Morning", symbol: "sunrise.fill", items: DailyChecklistCatalog.morning)
            section("Evening", symbol: "moon.stars.fill", items: DailyChecklistCatalog.evening)

            HStack(spacing: 12) {
                PrimaryButton(title: "Mark Done", icon: "checkmark.circle.fill") { markAll(true) }
                SecondaryButton(title: "Skip Today", icon: "xmark.circle") { markAll(false) }
            }
        }
        .toast($toast)
    }

    private var doneCount: Int { day.items.values.filter { $0 }.count }
    private var progressTitle: String {
        if progress >= 1 { return "All done!" }
        if progress >= 0.5 { return "Good progress" }
        if progress > 0 { return "Getting started" }
        return "Let's begin"
    }

    private func section(_ title: String, symbol: String, items: [DailyChecklistCatalog.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            VStack(spacing: 10) {
                ForEach(items) { item in
                    let done = day.items[item.id] ?? false
                    Button { toggle(item.id, to: !done) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(done ? Theme.amberGradient : Theme.background.asGradient)
                                    .frame(width: 30, height: 30)
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke, lineWidth: done ? 0 : 1))
                                if done { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white) }
                            }
                            Image(systemName: item.symbol).foregroundColor(done ? Theme.textFaint : Theme.amberDeep).frame(width: 22)
                            Text(item.title).font(.roostBody)
                                .foregroundColor(done ? Theme.textFaint : Theme.textPrimary)
                                .strikethrough(done, color: Theme.textFaint)
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func toggle(_ id: String, to value: Bool) {
        withAnimation(Metric.spring) { store.setChecklist(id, done: value) }
        refresh.toggle()
    }

    private func markAll(_ value: Bool) {
        withAnimation(Metric.spring) {
            for item in DailyChecklistCatalog.items { store.setChecklist(item.id, done: value) }
        }
        if value {
            store.log(CareLog(kind: .note, title: "Daily checklist completed"))
            toast = Toast(message: "All checks marked done")
        } else {
            toast = Toast(message: "Today's checks cleared", symbol: "xmark.circle.fill")
        }
        refresh.toggle()
    }
}
