//
//  Hubs.swift
//
//  The Care, Routes and More tab hubs. Each is a navigation backbone that links
//  to the fully-built functional screens.
//

import SwiftUI

private struct HubLink: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let destination: AnyView
}

private struct HubGrid: View {
    let links: [HubLink]
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(links) { link in
                NavigationLink(destination: link.destination) {
                    RoostCard(padding: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            IconBadge(symbol: link.symbol, tint: link.tint, size: 42)
                            Text(link.title).font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(link.subtitle).font(.roost(11, .medium)).foregroundColor(Theme.textSecondary)
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 118, alignment: .top)
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

// MARK: - Care Hub (Care Logs)

struct CareHubView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var showQuickAdd = false

    private var links: [HubLink] {
        [
            HubLink(title: "Daily Checklist", subtitle: "Morning & evening checks", symbol: "list.bullet", tint: Theme.ok, destination: AnyView(DailyChecklistView())),
            HubLink(title: "Feed Planner", subtitle: "Portions & stock", symbol: "bag.fill", tint: Theme.amberDeep, destination: AnyView(FeedPlannerView())),
            HubLink(title: "Water Log", subtitle: "Water, heat & vents", symbol: "drop.fill", tint: Theme.info, destination: AnyView(WaterLogView())),
            HubLink(title: "Observations", subtitle: "Health watch", symbol: "stethoscope", tint: Theme.barnRed, destination: AnyView(HealthObservationView())),
            HubLink(title: "Cleaning", subtitle: "Plan & sanitation", symbol: "sparkles", tint: Color(hex: 0x6FA45C), destination: AnyView(CleaningScheduleView())),
            HubLink(title: "Notes", subtitle: "Structured cards", symbol: "note.text", tint: Theme.wood, destination: AnyView(NotesBoardView())),
            HubLink(title: "Photo Markup", subtitle: "Mark problem areas", symbol: "photo.fill", tint: Color(hex: 0x8A6BB0), destination: AnyView(PhotoMarkupView())),
            HubLink(title: "Day Review", subtitle: "Close out the day", symbol: "moon.stars.fill", tint: Theme.rust, destination: AnyView(DailyReviewView()))
        ]
    }

    var body: some View {
        ScreenScaffold(title: "Care Logs", subtitle: "Everyday coop care & repairs",
                       trailingIcon: "plus", trailingAction: { showQuickAdd = true }) {
            PrimaryButton(title: "Quick Add Record", icon: "bolt.fill") { showQuickAdd = true }
            HubGrid(links: links)

            SectionHeader(title: "Recent", subtitle: "\(store.logsToday.count) records today")
            if store.logs.isEmpty {
                RoostCard { EmptyState(symbol: "note.text", title: "No records yet",
                                       message: "Log feeding, water, repairs and more.") }
            } else {
                ForEach(store.logs.prefix(6)) { log in
                    RoostCard(padding: 12) {
                        HStack(spacing: 12) {
                            IconBadge(symbol: log.kind.symbol, tint: log.kind.tint, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.title).font(.roost(14, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                Text("\(log.kind.title) · \(store.zoneName(log.zoneID))").font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Text(FarmStore.shortDate(log.date)).font(.roost(10, .medium)).foregroundColor(Theme.textFaint)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView().environmentObject(store).environmentObject(settings)
        }
    }
}

// MARK: - Routes Hub

struct RoutesHubView: View {
    @EnvironmentObject var store: FarmStore

    var body: some View {
        ScreenScaffold(title: "Routes", subtitle: "Care rounds & transport") {
            NavigationLink(destination: RoutePlannerView()) {
                RoostCard {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "map.fill", tint: Theme.amberDeep, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Care Route").font(.roost(17, .bold)).foregroundColor(Theme.textPrimary)
                            if let route = store.routes.first {
                                Text("\(route.stops.count) stops · ~\(route.totalMinutes) min").font(.roostCaption).foregroundColor(Theme.textSecondary)
                            } else {
                                Text("Build your walking round").font(.roostCaption).foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Theme.textFaint)
                    }
                }
            }.buttonStyle(PressableStyle())

            NavigationLink(destination: TransportPrepView()) {
                RoostCard {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "car.fill", tint: Theme.wood, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Transport Prep").font(.roost(17, .bold)).foregroundColor(Theme.textPrimary)
                            Text("\(store.crates.count) crates · \(store.crates.filter { $0.loaded }.count) loaded").font(.roostCaption).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Theme.textFaint)
                    }
                }
            }.buttonStyle(PressableStyle())

            if let route = store.routes.first, !route.stops.isEmpty {
                SectionHeader(title: "Today's Round")
                RoostCard {
                    VStack(spacing: 0) {
                        ForEach(Array(route.stops.enumerated()), id: \.element.id) { idx, stop in
                            HStack(spacing: 12) {
                                Text("\(idx + 1)").font(.roost(13, .bold)).foregroundColor(.white)
                                    .frame(width: 26, height: 26).background(Circle().fill(Theme.amber))
                                Text(stop.label).font(.roostBody).foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(stop.minutes)m").font(.roostCaption).foregroundColor(Theme.textFaint)
                            }
                            .padding(.vertical, 8)
                            if idx < route.stops.count - 1 { Divider().background(Theme.stroke) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - More Hub

struct MoreHubView: View {
    @EnvironmentObject var store: FarmStore

    private var links: [HubLink] {
        [
            HubLink(title: "Inventory", subtitle: "Supplies & low stock", symbol: "shippingbox.fill", tint: Theme.wood, destination: AnyView(InventoryShelfView())),
            HubLink(title: "Costs", subtitle: "Farm spending", symbol: "dollarsign.circle.fill", tint: Theme.rust, destination: AnyView(CostTrackerView())),
            HubLink(title: "Tasks", subtitle: "Repairs & to-dos", symbol: "checkmark.square.fill", tint: Theme.amberDeep, destination: AnyView(TaskBoardView())),
            HubLink(title: "Reminders", subtitle: "Local alerts", symbol: "bell.fill", tint: Theme.warn, destination: AnyView(ReminderQueueView())),
            HubLink(title: "Risk Flags", subtitle: "What to check first", symbol: "flag.fill", tint: Theme.danger, destination: AnyView(RiskFlagsView())),
            HubLink(title: "Weekly Trends", subtitle: "Charts & analytics", symbol: "chart.bar.fill", tint: Theme.info, destination: AnyView(WeeklyAnalyticsView())),
            HubLink(title: "Compare", subtitle: "Groups & zones", symbol: "chart.bar.xaxis", tint: Color(hex: 0x8A6BB0), destination: AnyView(TrendCompareView())),
            HubLink(title: "Capacity", subtitle: "Space & perch", symbol: "gauge", tint: Theme.ok, destination: AnyView(CapacityCalculatorView())),
            HubLink(title: "Reports", subtitle: "Build & export", symbol: "doc.text.fill", tint: Theme.barnRed, destination: AnyView(ReportBuilderView())),
            HubLink(title: "Zones", subtitle: "Coops & pens", symbol: "square.grid.2x2.fill", tint: Theme.amber, destination: AnyView(CoopZonesView())),
            HubLink(title: "Settings", subtitle: "App preferences", symbol: "gearshape.fill", tint: Theme.textSecondary, destination: AnyView(SettingsView()))
        ]
    }

    var body: some View {
        ScreenScaffold(title: "More", subtitle: "Inventory, analytics, reports & settings") {
            HubGrid(links: links)
        }
    }
}
