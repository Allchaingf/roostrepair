//
//  WeeklyAnalyticsView.swift — Screen 18: Weekly Trends
//
//  Charts for care regularity, record counts, costs and stock — no spreadsheets.
//  Filter the range and compare this week with last week.
//

import SwiftUI

struct WeeklyAnalyticsView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var range = 7
    @State private var compare = false

    private var sym: String { settings.currencySymbol }

    var body: some View {
        DetailScaffold(title: "Weekly Trends") {
            HStack(spacing: 8) {
                Image(systemName: "line.horizontal.3.decrease.circle").foregroundColor(Theme.textFaint)
                ForEach([7, 14, 30], id: \.self) { d in
                    SelectChip(text: "\(d)d", selected: range == d) { withAnimation(Metric.spring) { range = d } }
                }
                Spacer()
            }
            PillButton(title: compare ? "Comparing Weeks" : "Compare Weeks", icon: "arrow.left.arrow.right",
                       tint: Theme.amberDeep, filled: compare) { withAnimation(Metric.spring) { compare.toggle() } }
                .frame(maxWidth: .infinity, alignment: .leading)

            let metrics = store.recentMetrics(days: range)

            // Records per day (line)
            RoostCard {
                VStack(alignment: .leading, spacing: 12) {
                    chartTitle("Records per day", "\(metrics.reduce(0) { $0 + $1.logs }) total")
                    LineChart(values: metrics.map { Double($0.logs) },
                              labels: stride(from: 0, to: metrics.count, by: max(1, metrics.count / 7)).map { metrics[$0].label },
                              tint: Theme.amber)
                }
            }

            // Care consistency (bars)
            RoostCard {
                VStack(alignment: .leading, spacing: 12) {
                    chartTitle("Care consistency", "\(Int(store.weeklyConsistency * 100))% avg")
                    BarChart(data: metrics.suffix(7).map { ($0.label, $0.completion * 100, Theme.ok) }, height: 120)
                }
            }

            // Cost trend (line)
            RoostCard {
                VStack(alignment: .leading, spacing: 12) {
                    chartTitle("Daily cost", metrics.reduce(0) { $0 + $1.cost }.money(sym))
                    LineChart(values: metrics.map { $0.cost },
                              labels: stride(from: 0, to: metrics.count, by: max(1, metrics.count / 7)).map { metrics[$0].label },
                              tint: Theme.rust)
                }
            }

            // Records by kind
            let byKind = store.logsByKind(days: range)
            if !byKind.isEmpty {
                RoostCard {
                    VStack(alignment: .leading, spacing: 12) {
                        chartTitle("Records by type", "")
                        let maxV = Double(byKind.map { $0.1 }.max() ?? 1)
                        ForEach(byKind, id: \.0) { kind, count in
                            HBar(label: kind.title, value: Double(count), maxValue: maxV, tint: kind.tint, valueText: "\(count)")
                        }
                    }
                }
            }

            if compare { compareCard }

            // Inventory snapshot
            RoostCard {
                VStack(alignment: .leading, spacing: 10) {
                    chartTitle("Stock health", "\(store.lowStock.count) low")
                    HStack(spacing: 12) {
                        miniStat("\(store.inventory.count)", "items", Theme.wood)
                        miniStat("\(store.lowStock.count)", "low", store.lowStock.isEmpty ? Theme.ok : Theme.danger)
                        miniStat("\(store.tasks.filter { !$0.done }.count)", "open tasks", Theme.amberDeep)
                    }
                }
            }
        }
    }

    private var compareCard: some View {
        let thisWeek = window(0, 7)
        let lastWeek = window(7, 14)
        return RoostCard {
            VStack(alignment: .leading, spacing: 12) {
                chartTitle("This week vs last", "")
                compareRow("Records", thisWeek.records, lastWeek.records, isMoney: false)
                Divider().background(Theme.stroke)
                compareRow("Cost", thisWeek.cost, lastWeek.cost, isMoney: true)
            }
        }
    }

    private func window(_ from: Int, _ to: Int) -> (records: Double, cost: Double) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -to, to: now)!
        let end = cal.date(byAdding: .day, value: -from, to: now)!
        let recs = store.logs.filter { $0.date >= start && $0.date < end }.count
        let cost = store.costs.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.amount }
        return (Double(recs), cost)
    }

    private func compareRow(_ title: String, _ now: Double, _ prev: Double, isMoney: Bool) -> some View {
        let delta = now - prev
        let up = delta >= 0
        return HStack {
            Text(title).font(.roostBody).foregroundColor(Theme.textPrimary)
            Spacer()
            Text(isMoney ? now.money(sym) : "\(Int(now))").font(.roost(16, .bold)).foregroundColor(Theme.textPrimary)
            HStack(spacing: 3) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.system(size: 11, weight: .bold))
                Text(isMoney ? abs(delta).money(sym) : "\(Int(abs(delta)))").font(.roost(12, .bold))
            }
            .foregroundColor(up ? Theme.ok : Theme.danger)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill((up ? Theme.ok : Theme.danger).opacity(0.15)))
        }
    }

    private func chartTitle(_ title: String, _ sub: String) -> some View {
        HStack {
            Text(title).font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
            Spacer()
            if !sub.isEmpty { Text(sub).font(.roost(13, .semibold)).foregroundColor(Theme.amberDeep) }
        }
    }
    private func miniStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.roost(18, .bold)).foregroundColor(tint)
            Text(label).font(.roost(10, .medium)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
    }
}
