//
//  CostTrackerView.swift — Screen 11: Farm Costs
//
//  Log spending by category and group. View this month's total, a category
//  breakdown and recent entries. "View Month" filters to the current month.
//

import SwiftUI

struct CostTrackerView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var monthOnly = false
    @State private var editing: CostEntry?
    @State private var showNew = false
    @State private var toast: Toast?

    private var visible: [CostEntry] {
        let base = store.costs.sorted { $0.date > $1.date }
        guard monthOnly else { return base }
        let cal = Calendar.current
        return base.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }
    private var sym: String { settings.currencySymbol }
    private var total: Double { visible.reduce(0) { $0 + $1.amount } }

    var body: some View {
        DetailScaffold(title: "Farm Costs", trailingIcon: "plus", trailingAction: { showNew = true }) {
            RoostCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(monthOnly ? "This month" : "All time").font(.roostCaption).foregroundColor(Theme.textSecondary)
                    Text(total.money(sym)).font(.roost(30, .bold)).foregroundColor(Theme.amberDeep)
                    Text("\(visible.count) entries").font(.roostCaption).foregroundColor(Theme.textFaint)
                }
            }

            HStack(spacing: 8) {
                PillButton(title: monthOnly ? "This Month" : "View Month", icon: "calendar",
                           filled: monthOnly) { withAnimation(Metric.spring) { monthOnly.toggle() } }
                Spacer()
                PillButton(title: "Add Cost", icon: "plus", tint: Theme.amberDeep, filled: true) { showNew = true }
            }

            let breakdown = store.costByCategory(days: monthOnly ? 31 : 3650)
            if !breakdown.isEmpty {
                RoostCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("By Category").font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                        let maxV = breakdown.map { $0.1 }.max() ?? 1
                        ForEach(breakdown, id: \.0) { cat, value in
                            HBar(label: cat.title, value: value, maxValue: maxV, tint: cat.tint, valueText: value.money(sym))
                        }
                    }
                }
            }

            SectionHeader(title: "Entries")
            if visible.isEmpty {
                RoostCard { EmptyState(symbol: "dollarsign.circle", title: "No costs logged",
                                       message: "Track feed, repairs, bedding and more.") }
            } else {
                ForEach(visible) { cost in costCard(cost) }
            }
        }
        .sheet(isPresented: $showNew) {
            CostEditorView(cost: nil) { toast = Toast(message: "Cost added") }.environmentObject(store)
        }
        .sheet(item: $editing) { c in
            CostEditorView(cost: c) { toast = Toast(message: "Cost saved") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func costCard(_ cost: CostEntry) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: cost.category.symbol, tint: cost.category.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cost.title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text("\(cost.category.title)\(cost.groupID != nil ? " · " + store.groupName(cost.groupID) : "") · \(FarmStore.shortDate(cost.date))")
                        .font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                Text(cost.amount.money(sym)).font(.roost(16, .bold)).foregroundColor(Theme.amberDeep)
                Menu {
                    Button { editing = cost } label: { Label("Edit", systemImage: "pencil") }
                    Button { store.deleteCost(cost) } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 28, height: 28)
                }
            }
        }
    }
}

// MARK: - Cost editor

struct CostEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var cost: CostEntry?
    var onSave: () -> Void

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var category: CostCategory = .feed
    @State private var groupID: UUID?
    @State private var date = Date()

    var body: some View {
        SheetScaffold(title: cost == nil ? "Add Cost" : "Edit Cost",
                      saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Description", placeholder: "e.g. Feed sack", text: $title, icon: "cart.fill")
            RoostNumberField(title: "Amount", value: $amount, unit: UserDefaults.standard.string(forKey: "set.currency") ?? "$", icon: "dollarsign.circle.fill")

            Text("CATEGORY").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(CostCategory.allCases) { c in
                    SelectChip(text: c.title, symbol: c.symbol, selected: category == c, tint: c.tint) { category = c }
                }
            }

            Text("GROUP (optional)").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: groupID == nil) { groupID = nil }
                    ForEach(store.groups) { g in
                        SelectChip(text: g.name, symbol: g.type.symbol, selected: groupID == g.id, tint: g.color) { groupID = g.id }
                    }
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .accentColor(Theme.amberDeep).foregroundColor(Theme.textPrimary)
        }
        .onAppear {
            if let c = cost { title = c.title; amount = c.amount; category = c.category; groupID = c.groupID; date = c.date }
        }
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, amount > 0 else { return }
        if var c = cost {
            c.title = trimmed; c.amount = amount; c.category = category; c.groupID = groupID; c.date = date
            store.updateCost(c)
        } else {
            store.addCost(CostEntry(title: trimmed, amount: amount, category: category, groupID: groupID, date: date))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
