//
//  InventoryShelfView.swift — Screen 10: Supplies
//
//  Stock of feed, bedding, supplements, hardware and waterer parts. Set a
//  minimum level to get a local low-stock flag; adjust stock inline.
//

import SwiftUI

struct InventoryShelfView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings
    @State private var lowOnly = false
    @State private var editing: InventoryItem?
    @State private var showNew = false
    @State private var toast: Toast?

    private var visible: [InventoryItem] {
        let base = store.inventory.sorted { $0.isLow && !$1.isLow }
        return lowOnly ? base.filter { $0.isLow } : base
    }

    var body: some View {
        DetailScaffold(title: "Supplies", trailingIcon: "plus", trailingAction: { showNew = true }) {
            HStack(spacing: 12) {
                StatTile(value: "\(store.inventory.count)", label: "Items", symbol: "shippingbox.fill")
                StatTile(value: "\(store.lowStock.count)", label: "Low stock", symbol: "exclamationmark.triangle.fill",
                         tint: store.lowStock.isEmpty ? Theme.ok : Theme.danger)
            }

            HStack(spacing: 8) {
                PillButton(title: lowOnly ? "Showing Low" : "Low Stock", icon: "line.horizontal.3.decrease.circle",
                           tint: Theme.danger, filled: lowOnly) { withAnimation(Metric.spring) { lowOnly.toggle() } }
                Spacer()
                PillButton(title: "Add Item", icon: "plus", tint: Theme.amberDeep, filled: true) { showNew = true }
            }

            if visible.isEmpty {
                RoostCard { EmptyState(symbol: "shippingbox", title: lowOnly ? "Nothing low" : "No supplies yet",
                                       message: lowOnly ? "All items are above their minimum." : "Add feed, bedding, parts and more.") }
            } else {
                ForEach(visible) { item in itemCard(item) }
            }
        }
        .sheet(isPresented: $showNew) {
            InventoryEditorView(item: nil) { toast = Toast(message: "Item added") }.environmentObject(store)
        }
        .sheet(item: $editing) { i in
            InventoryEditorView(item: i) { toast = Toast(message: "Item saved") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func itemCard(_ item: InventoryItem) -> some View {
        RoostCard(padding: 14) {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    IconBadge(symbol: item.category.symbol, tint: item.isLow ? Theme.danger : Theme.wood)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(item.name).font(.roost(16, .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                            if item.isLow { TagChip(text: "Low", symbol: "exclamationmark", tint: Theme.danger) }
                        }
                        Text("\(item.category.title) · min \(item.minLevel.clean) \(item.unit)")
                            .font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    Menu {
                        Button { editing = item } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.deleteItem(item) } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 30, height: 30)
                    }
                }
                HStack(spacing: 14) {
                    stockButton("minus") { store.adjustStock(item, by: -1) }
                    VStack(spacing: 0) {
                        Text(item.quantity.clean).font(.roost(20, .bold)).foregroundColor(item.isLow ? Theme.danger : Theme.amberDeep)
                        Text(item.unit).font(.roost(10, .medium)).foregroundColor(Theme.textFaint)
                    }
                    .frame(minWidth: 60)
                    stockButton("plus") { store.adjustStock(item, by: 1) }
                    Spacer()
                    // Stock bar relative to 2x min level.
                    GeometryReader { geo in
                        let cap = max(item.minLevel * 2, item.quantity, 1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.stroke.opacity(0.5)).frame(height: 8)
                            Capsule().fill(item.isLow ? Theme.danger : Theme.ok)
                                .frame(width: max(6, geo.size.width * CGFloat(item.quantity / cap)), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private func stockButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(Metric.spring) { action() } }) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                .frame(width: 34, height: 34).background(Circle().fill(Theme.amber))
        }.buttonStyle(PressableStyle())
    }
}

// MARK: - Inventory editor

struct InventoryEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var item: InventoryItem?
    var onSave: () -> Void

    @State private var name = ""
    @State private var category: InventoryCategory = .feed
    @State private var quantity: Double = 0
    @State private var unit = "units"
    @State private var minLevel: Double = 0

    var body: some View {
        SheetScaffold(title: item == nil ? "Add Item" : "Edit Item",
                      saveEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Name", placeholder: "e.g. Layer Pellets", text: $name, icon: "tag.fill")

            Text("CATEGORY").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(InventoryCategory.allCases) { c in
                    SelectChip(text: c.title, symbol: c.symbol, selected: category == c) { category = c }
                }
            }

            HStack(spacing: 12) {
                RoostNumberField(title: "Quantity", value: $quantity, icon: "number")
                RoostField(title: "Unit", placeholder: "kg / pcs", text: $unit)
            }
            RoostNumberField(title: "Minimum level (low-stock flag)", value: $minLevel, icon: "exclamationmark.triangle")
        }
        .onAppear {
            if let i = item { name = i.name; category = i.category; quantity = i.quantity; unit = i.unit; minLevel = i.minLevel }
        }
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var i = item {
            i.name = trimmed; i.category = category; i.quantity = quantity; i.unit = unit; i.minLevel = minLevel
            store.updateItem(i)
        } else {
            store.addItem(InventoryItem(name: trimmed, category: category, quantity: quantity, unit: unit, minLevel: minLevel))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
