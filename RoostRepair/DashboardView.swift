//
//  DashboardView.swift  — Screen 1: Today Overview
//
//  The home board. Shows flock status, the day's priority actions and quick
//  links. The layout adapts to the board mode chosen in onboarding
//  (coop map / route list / ledger).
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    var switchTab: (AppTab) -> Void

    @State private var showQuickAdd = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
    private var dateText: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM"; return f.string(from: Date())
    }

    var body: some View {
        ScreenScaffold(title: "Today Overview", subtitle: "\(greeting) · \(dateText)") {

            statRow
            actionButtons

            // Board mode-specific overview.
            switch settings.viewMode {
            case .coopMap:   coopMapSection
            case .routeList: routeListSection
            case .ledger:    ledgerSection
            }

            prioritySection
            quickGrid
            recentSection
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView().environmentObject(store).environmentObject(settings)
        }
    }

    // MARK: Stats
    private var statRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(store.groups.count)", label: "Groups", symbol: "oval.fill")
            StatTile(value: "\(store.totalBirds)", label: "Birds", symbol: "number", tint: Theme.wood)
            RoostCard(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consistency").font(.roostCaption).foregroundColor(Theme.textSecondary)
                    ProgressRing(progress: store.weeklyConsistency, size: 58, lineWidth: 8)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            PrimaryButton(title: "Add Record", icon: "plus.circle.fill") { showQuickAdd = true }
            NavigationLink(destination: WeeklyAnalyticsView()) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                    Text("Analytics").font(.roost(17, .semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .foregroundColor(Theme.amberDeep)
                .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.amberSoft))
                .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(Theme.amber.opacity(0.5), lineWidth: 1))
            }
        }
    }

    // MARK: Coop map mode
    private var coopMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Coop Map", subtitle: "Zones & who lives where")
            if store.zones.isEmpty {
                RoostCard { EmptyState(symbol: "square.grid.2x2", title: "No zones yet",
                                       message: "Add coops and runs to see your map.") }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(store.sortedZones) { zone in
                        zoneCard(zone)
                    }
                }
            }
        }
    }

    private func zoneCard(_ zone: Zone) -> some View {
        let groupsHere = store.groups.filter { $0.zoneID == zone.id }
        let birds = groupsHere.reduce(0) { $0 + $1.count }
        return RoostCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    IconBadge(symbol: zone.kind.symbol, tint: Theme.wood, size: 36)
                    Spacer()
                    if zone.kind == .quarantine {
                        TagChip(text: "Care", symbol: "cross.case.fill", tint: Theme.barnRed)
                    }
                }
                Text(zone.name).font(.roost(16, .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                Text("\(groupsHere.count) group\(groupsHere.count == 1 ? "" : "s") · \(birds) birds")
                    .font(.roostCaption).foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: Route list mode
    private var routeListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Today's Round", subtitle: "Ordered walk-through",
                          actionTitle: "Routes") { switchTab(.routes) }
            let stops = store.routes.first?.stops ?? []
            if stops.isEmpty {
                RoostCard { EmptyState(symbol: "map", title: "No route yet",
                                       message: "Build a care route to see your round.") }
            } else {
                RoostCard {
                    VStack(spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { idx, stop in
                            HStack(spacing: 12) {
                                Text("\(idx + 1)").font(.roost(13, .bold)).foregroundColor(.white)
                                    .frame(width: 26, height: 26).background(Circle().fill(Theme.amber))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.label).font(.roostBody).foregroundColor(Theme.textPrimary)
                                    Text(store.zoneName(stop.zoneID)).font(.roostCaption).foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                Text("\(stop.minutes)m").font(.roostCaption).foregroundColor(Theme.textFaint)
                            }
                            .padding(.vertical, 8)
                            if idx < stops.count - 1 { Divider().background(Theme.stroke) }
                        }
                    }
                }
            }
        }
    }

    // MARK: Ledger mode
    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Ledger", subtitle: "Most recent records")
            RoostCard(padding: 8) {
                VStack(spacing: 0) {
                    if store.logs.isEmpty {
                        EmptyState(symbol: "tablecells", title: "No records yet",
                                   message: "Tap Add Record to begin your ledger.")
                    } else {
                        ForEach(store.logs.prefix(6)) { log in
                            HStack(spacing: 10) {
                                Image(systemName: log.kind.symbol).foregroundColor(log.kind.tint)
                                    .font(.system(size: 14)).frame(width: 22)
                                Text(log.title).font(.roost(14, .medium)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                Spacer()
                                Text(relative(log.date)).font(.roost(11, .medium)).foregroundColor(Theme.textFaint)
                            }
                            .padding(.vertical, 7).padding(.horizontal, 8)
                            Divider().background(Theme.stroke.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    // MARK: Priorities (next actions)
    private var prioritySection: some View {
        let flags = store.riskFlags.prefix(3)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Needs Attention").font(.roost(18, .bold)).foregroundColor(Theme.textPrimary)
                    Text(flags.isEmpty ? "All clear" : "\(store.riskFlags.count) item(s)")
                        .font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                NavigationLink(destination: RiskFlagsView()) {
                    Text("All flags").font(.roost(14, .semibold)).foregroundColor(Theme.amberDeep)
                }
            }
            if flags.isEmpty {
                RoostCard {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "checkmark.seal.fill", tint: Theme.ok)
                        Text("Nothing urgent right now. Nice work!")
                            .font(.roostBody).foregroundColor(Theme.textPrimary)
                    }
                }
            } else {
                ForEach(Array(flags)) { flag in
                    NavigationLink(destination: RiskFlagsView()) {
                        RoostCard(padding: 14) {
                            HStack(spacing: 12) {
                                IconBadge(symbol: flag.symbol, tint: flag.severity.tint, size: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(flag.title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(flag.detail).font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(Theme.textFaint).font(.system(size: 13, weight: .bold))
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: Quick grid
    private struct QuickLink: Identifiable { let id = UUID(); let title: String; let symbol: String; let tint: Color; let dest: AnyView }
    private var quickLinks: [QuickLink] {
        [
            QuickLink(title: "Checklist", symbol: "list.bullet", tint: Theme.ok, dest: AnyView(DailyChecklistView())),
            QuickLink(title: "Capacity", symbol: "gauge", tint: Theme.info, dest: AnyView(CapacityCalculatorView())),
            QuickLink(title: "Reminders", symbol: "bell.fill", tint: Theme.amberDeep, dest: AnyView(ReminderQueueView())),
            QuickLink(title: "Tasks", symbol: "checkmark.square.fill", tint: Theme.wood, dest: AnyView(TaskBoardView())),
            QuickLink(title: "Day Review", symbol: "moon.stars.fill", tint: Theme.barnRed, dest: AnyView(DailyReviewView())),
            QuickLink(title: "Risk Flags", symbol: "flag.fill", tint: Theme.danger, dest: AnyView(RiskFlagsView()))
        ]
    }
    private var quickGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Quick Access")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(quickLinks) { link in
                    NavigationLink(destination: link.dest) {
                        VStack(spacing: 8) {
                            IconBadge(symbol: link.symbol, tint: link.tint, size: 44)
                            Text(link.title).font(.roost(12, .semibold)).foregroundColor(Theme.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: Recent
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent Records", subtitle: "\(store.logsToday.count) today",
                          actionTitle: "Care") { switchTab(.care) }
            if store.logs.isEmpty {
                RoostCard { EmptyState(symbol: "note.text", title: "No records yet",
                                       message: "Your feeding, water and repair logs appear here.") }
            } else {
                ForEach(store.logs.prefix(4)) { log in
                    RoostCard(padding: 12) {
                        HStack(spacing: 12) {
                            IconBadge(symbol: log.kind.symbol, tint: log.kind.tint, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                Text("\(log.kind.title) · \(store.zoneName(log.zoneID))")
                                    .font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Text(relative(log.date)).font(.roost(11, .medium)).foregroundColor(Theme.textFaint)
                        }
                    }
                }
            }
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
