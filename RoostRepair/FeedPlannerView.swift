//
//  FeedPlannerView.swift — Screen 4: Feed Portions
//
//  Plan feed portions per group and day. Saving a portion logs a feeding record
//  and deducts from the chosen feed stock; a forecast shows how many days of
//  feed remain at the current rate.
//

import SwiftUI

struct FeedPlannerView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings

    @State private var groupID: UUID?
    @State private var gramsPerBird: Double = 120
    @State private var days: Int = 7
    @State private var feedItemID: UUID?
    @State private var toast: Toast?
    @State private var showStock = false

    private var group: BirdGroup? { store.group(groupID) ?? store.groups.first }
    private var feedItems: [InventoryItem] { store.inventory.filter { $0.category == .feed } }
    private var feedItem: InventoryItem? { store.inventory.first { $0.id == feedItemID } ?? feedItems.first }

    // kg needed for the whole plan.
    private var totalKg: Double {
        guard let g = group else { return 0 }
        return Double(g.count) * gramsPerBird * Double(days) / 1000.0
    }
    private var dailyKgAllGroups: Double {
        store.groups.reduce(0) { $0 + Double($1.count) * gramsPerBird / 1000.0 }
    }
    private var totalFeedStock: Double { feedItems.reduce(0) { $0 + $1.quantity } }
    private var daysRemaining: Int {
        guard dailyKgAllGroups > 0 else { return 0 }
        return Int(totalFeedStock / dailyKgAllGroups)
    }

    var body: some View {
        DetailScaffold(title: "Feed Portions") {
            if store.groups.isEmpty {
                RoostCard { EmptyState(symbol: "oval.fill", title: "No groups yet",
                                       message: "Create a bird group to plan feed.") }
            } else {
                RoostCard {
                    VStack(spacing: 14) {
                        fieldLabel("Group")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.groups) { g in
                                    SelectChip(text: g.name, symbol: g.type.symbol, selected: group?.id == g.id, tint: g.color) { groupID = g.id }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("GRAMS / BIRD / DAY").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                                Spacer()
                                Text("\(Int(gramsPerBird)) g").font(.roost(13, .bold)).foregroundColor(Theme.amberDeep)
                            }
                            Slider(value: $gramsPerBird, in: 40...250, step: 5).accentColor(Theme.amber)
                        }
                        RoostStepper(title: "Plan length (days)", value: $days, range: 1...60)
                    }
                }

                // Result
                RoostCard {
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plan needs").font(.roostCaption).foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.1f kg", totalKg)).font(.roost(26, .bold)).foregroundColor(Theme.amberDeep)
                            if let g = group {
                                Text("\(g.count) birds · \(days) days").font(.roostCaption).foregroundColor(Theme.textFaint)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Daily (all groups)").font(.roostCaption).foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.2f kg", dailyKgAllGroups)).font(.roost(18, .bold)).foregroundColor(Theme.textPrimary)
                        }
                    }
                }

                // Feed stock pick
                if !feedItems.isEmpty {
                    fieldLabel("Deduct from feed stock")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(feedItems) { item in
                                SelectChip(text: "\(item.name) (\(item.quantity.clean)\(item.unit))",
                                           symbol: "bag.fill", selected: (feedItem?.id == item.id)) { feedItemID = item.id }
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    PrimaryButton(title: "Add Portion", icon: "plus.circle.fill") { addPortion() }
                    SecondaryButton(title: "Update Stock", icon: "shippingbox.fill") { showStock = true }
                }

                // Forecast
                RoostCard {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "calendar.badge.clock", tint: daysRemaining < 5 ? Theme.danger : Theme.info, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Purchase forecast").font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                            Text(feedItems.isEmpty ? "Add a feed item to forecast." :
                                    "~\(daysRemaining) days of feed left (\(totalFeedStock.clean) kg in stock).")
                                .font(.roostCaption).foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showStock) {
            if let item = feedItem {
                InventoryEditorView(item: item) { toast = Toast(message: "Stock updated") }.environmentObject(store)
            } else {
                InventoryEditorView(item: nil) { toast = Toast(message: "Feed item added") }.environmentObject(store)
            }
        }
        .toast($toast)
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addPortion() {
        guard let g = group else { return }
        let dailyKg = Double(g.count) * gramsPerBird / 1000.0
        store.log(CareLog(kind: .feeding,
                          title: "Feed portion · \(g.name)",
                          detail: String(format: "%.0f g/bird · %.2f kg today", gramsPerBird, dailyKg),
                          groupID: g.id, zoneID: g.zoneID))
        // Deduct one day's portion from the chosen feed item.
        if let item = feedItem {
            store.adjustStock(item, by: -dailyKg)
        }
        toast = Toast(message: "Portion logged · stock reduced")
    }
}
