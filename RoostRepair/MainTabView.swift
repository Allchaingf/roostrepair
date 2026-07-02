//
//  MainTabView.swift
//  RoostRepair
//
//  Custom barn-themed bottom tab bar with five hubs. A floating amber Quick-Add
//  button sits center for the fastest path to logging a record.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard, groups, care, routes, more
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .dashboard: return "Board"
        case .groups:    return "Groups"
        case .care:      return "Care"
        case .routes:    return "Routes"
        case .more:      return "More"
        }
    }
    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .groups:    return "oval.fill"
        case .care:      return "list.bullet"
        case .routes:    return "map.fill"
        case .more:      return "ellipsis.circle.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var tab: AppTab = .dashboard
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Active tab content (own navigation stack per tab).
            Group {
                switch tab {
                case .dashboard: NavigationView { DashboardView(switchTab: switchTo) }.navigationViewStyle(.stack)
                case .groups:    NavigationView { GroupsView() }.navigationViewStyle(.stack)
                case .care:      NavigationView { CareHubView() }.navigationViewStyle(.stack)
                case .routes:    NavigationView { RoutesHubView() }.navigationViewStyle(.stack)
                case .more:      NavigationView { MoreHubView() }.navigationViewStyle(.stack)
                }
            }
            .transition(.opacity)

            tabBar
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView().environmentObject(store).environmentObject(settings)
        }
    }

    private func switchTo(_ t: AppTab) { withAnimation(Metric.spring) { tab = t } }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.dashboard)
            tabButton(.groups)
            quickAddButton
            tabButton(.routes)
            tabButton(.more)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.cardRaised)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func tabButton(_ t: AppTab) -> some View {
        Button(action: { switchTo(t) }) {
            VStack(spacing: 4) {
                Image(systemName: t.symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(t.title).font(.roost(10, .semibold))
            }
            .foregroundColor(tab == t ? Theme.amberDeep : Theme.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if tab == t {
                        RoundedRectangle(cornerRadius: 14).fill(Theme.amberSoft)
                    }
                }
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var quickAddButton: some View {
        Button(action: { showQuickAdd = true }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Theme.amberGradient))
                .shadow(color: Theme.amberDeep.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity)
        .offset(y: -10)
    }
}
