//
//  TrendCompareView.swift — Screen 19: Compare Groups
//
//  Compare groups or zones by records, costs and open tasks to see where the
//  workload sits. Select the items, then Apply.
//

import SwiftUI

struct TrendCompareView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings

    enum Mode: String, CaseIterable { case groups = "Groups", zones = "Zones" }
    @State private var mode: Mode = .groups
    @State private var selected: Set<UUID> = []
    @State private var applied = false

    private var sym: String { settings.currencySymbol }

    var body: some View {
        DetailScaffold(title: "Compare Groups") {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: mode) { _ in selected = []; applied = false }

            SectionHeader(title: "Select \(mode.rawValue)", subtitle: "\(selected.count) selected")
            if mode == .groups {
                if store.groups.isEmpty {
                    RoostCard { EmptyState(symbol: "oval.fill", title: "No groups", message: "Create groups to compare.") }
                } else {
                    selectionGrid(items: store.groups.map { ($0.id, $0.name, $0.type.symbol, $0.color) })
                }
            } else {
                if store.zones.isEmpty {
                    RoostCard { EmptyState(symbol: "square.dashed", title: "No zones", message: "Add zones to compare.") }
                } else {
                    selectionGrid(items: store.sortedZones.map { ($0.id, $0.name, $0.kind.symbol, Theme.wood) })
                }
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Apply", icon: "chart.bar.fill") { withAnimation(Metric.spring) { applied = true } }
                if !selected.isEmpty {
                    SecondaryButton(title: "Select All", icon: "list.bullet") { selectAll() }
                }
            }

            if applied && !selected.isEmpty { resultsSection }
        }
    }

    private func selectionGrid(items: [(UUID, String, String, Color)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items, id: \.0) { id, name, symbol, color in
                Button { toggle(id) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: symbol).foregroundColor(selected.contains(id) ? .white : color)
                        Text(name).font(.roost(14, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer()
                        Image(systemName: selected.contains(id) ? "checkmark.circle.fill" : "circle")
                    }
                    .padding(12)
                    .foregroundColor(selected.contains(id) ? .white : Theme.textPrimary)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall)
                        .fill(selected.contains(id) ? Theme.amberGradient : Theme.card.asGradient))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: selected.contains(id) ? 0 : 1))
                }.buttonStyle(PressableStyle())
            }
        }
    }

    private var resultsSection: some View {
        let data = selected.map { id -> (String, Color, Int, Double, Int) in
            if mode == .groups, let g = store.group(id) {
                let recs = store.logs.filter { $0.groupID == id }.count
                let cost = store.costFor(group: id)
                let tasks = 0
                return (g.name, g.color, recs, cost, tasks)
            } else if let z = store.zone(id) {
                let recs = store.logs.filter { $0.zoneID == id }.count
                let cost = 0.0
                let tasks = store.tasks.filter { $0.zoneID == id && !$0.done }.count
                return (z.name, Theme.wood, recs, cost, tasks)
            }
            return ("—", Theme.stroke, 0, 0, 0)
        }
        let maxRecs = Double(data.map { $0.2 }.max() ?? 1)
        let maxCost = data.map { $0.3 }.max() ?? 1
        let maxTasks = Double(data.map { $0.4 }.max() ?? 1)

        return VStack(spacing: 16) {
            RoostCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Records").font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                    ForEach(Array(data.enumerated()), id: \.offset) { _, d in
                        HBar(label: d.0, value: Double(d.2), maxValue: maxRecs, tint: d.1, valueText: "\(d.2)")
                    }
                }
            }
            if mode == .groups {
                RoostCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Costs").font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                        ForEach(Array(data.enumerated()), id: \.offset) { _, d in
                            HBar(label: d.0, value: d.3, maxValue: maxCost, tint: Theme.rust, valueText: d.3.money(sym))
                        }
                    }
                }
            } else {
                RoostCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Open tasks").font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                        ForEach(Array(data.enumerated()), id: \.offset) { _, d in
                            HBar(label: d.0, value: Double(d.4), maxValue: maxTasks, tint: Theme.amberDeep, valueText: "\(d.4)")
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        applied = false
    }
    private func selectAll() {
        selected = Set(mode == .groups ? store.groups.map { $0.id } : store.zones.map { $0.id })
    }
}
