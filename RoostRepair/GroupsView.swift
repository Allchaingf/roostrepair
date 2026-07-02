//
//  GroupsView.swift — Screen 22 (Bird Groups) + Screen 23 (Coop Zones)
//
//  Tab root with a segmented control between bird groups and coop zones.
//  Full create / edit / delete / flag / reorder, all persisted via FarmStore.
//

import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: FarmStore
    @State private var segment = 0   // 0 = groups, 1 = zones
    @State private var editingGroup: BirdGroup?
    @State private var showNewGroup = false
    @State private var toast: Toast?

    var body: some View {
        ScreenScaffold(title: segment == 0 ? "Bird Groups" : "Farm Zones",
                       subtitle: segment == 0 ? "\(store.groups.count) groups · \(store.totalBirds) birds"
                                              : "\(store.zones.count) zones",
                       trailingIcon: segment == 0 ? "plus" : nil,
                       trailingAction: segment == 0 ? { showNewGroup = true } : nil) {

            Picker("", selection: $segment) {
                Text("Groups").tag(0)
                Text("Zones").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())

            if segment == 0 { groupsList } else { CoopZonesInline() }
        }
        .sheet(isPresented: $showNewGroup) {
            GroupEditorView(group: nil) { toast = Toast(message: "Group added") }
                .environmentObject(store)
        }
        .sheet(item: $editingGroup) { g in
            GroupEditorView(group: g) { toast = Toast(message: "Group saved") }
                .environmentObject(store)
        }
        .toast($toast)
    }

    private var groupsList: some View {
        VStack(spacing: 12) {
            if store.groups.isEmpty {
                RoostCard { EmptyState(symbol: "oval.fill", title: "No groups yet",
                                       message: "Tap + to create your first bird group.") }
            } else {
                ForEach(store.groups) { group in
                    NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                        groupCard(group)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            SecondaryButton(title: "Create Group", icon: "plus.circle.fill") { showNewGroup = true }
        }
    }

    private func groupCard(_ group: BirdGroup) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(group.color.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: group.type.symbol).foregroundColor(group.color).font(.system(size: 20, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.name).font(.roost(16, .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        if group.flagged {
                            Image(systemName: "flag.fill").foregroundColor(Theme.danger).font(.system(size: 12))
                        }
                    }
                    Text("\(group.count) \(group.type.title.lowercased()) · \(store.zoneName(group.zoneID))")
                        .font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                Menu {
                    Button { editingGroup = group } label: { Label("Edit", systemImage: "pencil") }
                    Button { store.toggleGroupFlag(group) } label: {
                        Label(group.flagged ? "Remove flag" : "Flag for re-check",
                              systemImage: group.flagged ? "flag.slash" : "flag")
                    }
                    Button { store.deleteGroup(group) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }
}

// MARK: - Group editor

struct GroupEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var group: BirdGroup?
    var onSave: () -> Void

    @State private var name = ""
    @State private var type: BirdType = .chicken
    @State private var count = 6
    @State private var zoneID: UUID?
    @State private var colorHex: UInt = 0xE8A33D
    @State private var flagged = false

    private let palette: [UInt] = [0xE8A33D, 0xCE7C24, 0x4E8FA8, 0xA8392E, 0x6FA45C, 0x8A6BB0, 0x7A5230]

    var body: some View {
        SheetScaffold(title: group == nil ? "Create Group" : "Edit Group",
                      saveEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Name", placeholder: "e.g. Brown Layers", text: $name, icon: "tag.fill")

            fieldLabel("Bird type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BirdType.allCases) { t in
                        SelectChip(text: t.title, symbol: t.symbol, selected: type == t) { type = t }
                    }
                }
            }

            RoostStepper(title: "Count", value: $count, range: 1...5000)

            fieldLabel("Zone")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "Unassigned", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }

            fieldLabel("Colour marker")
            HStack(spacing: 12) {
                ForEach(palette, id: \.self) { hex in
                    Button { colorHex = hex } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0))
                            .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                    }
                }
            }

            Toggle(isOn: $flagged) {
                Label("Flag for re-check", systemImage: "flag.fill")
                    .font(.roostBody).foregroundColor(Theme.textPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.amber))
            .padding(.top, 4)
        }
        .onAppear(perform: load)
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        guard let g = group else { return }
        name = g.name; type = g.type; count = g.count
        zoneID = g.zoneID; colorHex = g.colorHex; flagged = g.flagged
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var g = group {
            g.name = trimmed; g.type = type; g.count = count
            g.zoneID = zoneID; g.colorHex = colorHex; g.flagged = flagged
            store.updateGroup(g)
        } else {
            store.addGroup(BirdGroup(name: trimmed, type: type, count: count,
                                     zoneID: zoneID, colorHex: colorHex, flagged: flagged))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Group detail

struct GroupDetailView: View {
    @EnvironmentObject var store: FarmStore
    var groupID: UUID
    @State private var editing: BirdGroup?

    private var group: BirdGroup? { store.group(groupID) }

    var body: some View {
        DetailScaffold(title: group?.name ?? "Group",
                       trailingIcon: "pencil",
                       trailingAction: { editing = group }) {
            if let group = group {
                RoostCard {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(group.color.opacity(0.2)).frame(width: 64, height: 64)
                            Image(systemName: group.type.symbol).foregroundColor(group.color).font(.system(size: 28, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name).font(.roost(20, .bold)).foregroundColor(Theme.textPrimary)
                            Text("\(group.count) \(group.type.title.lowercased())").font(.roostBody).foregroundColor(Theme.textSecondary)
                            Text("Zone: \(store.zoneName(group.zoneID))").font(.roostCaption).foregroundColor(Theme.textFaint)
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 12) {
                    StatTile(value: "\(store.logs.filter { $0.groupID == group.id }.count)", label: "Records", symbol: "note.text")
                    StatTile(value: store.costFor(group: group.id).money(settingsSymbol), label: "Costs", symbol: "dollarsign.circle", tint: Theme.rust)
                }

                Button { store.toggleGroupFlag(group) } label: {
                    HStack {
                        Image(systemName: group.flagged ? "flag.slash" : "flag.fill")
                        Text(group.flagged ? "Remove re-check flag" : "Flag for re-check").font(.roost(15, .semibold))
                        Spacer()
                    }
                    .padding(14).foregroundColor(group.flagged ? Theme.textSecondary : Theme.danger)
                    .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())

                SectionHeader(title: "Recent records")
                let glogs = store.logs.filter { $0.groupID == group.id }
                if glogs.isEmpty {
                    RoostCard { EmptyState(symbol: "note.text", title: "No records",
                                           message: "Records logged for this group appear here.") }
                } else {
                    ForEach(glogs.prefix(8)) { log in
                        RoostCard(padding: 12) {
                            HStack(spacing: 12) {
                                IconBadge(symbol: log.kind.symbol, tint: log.kind.tint, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.title).font(.roost(14, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                    Text(FarmStore.shortDate(log.date)).font(.roostCaption).foregroundColor(Theme.textFaint)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            } else {
                EmptyState(symbol: "oval.fill", title: "Group removed", message: "This group no longer exists.")
            }
        }
        .sheet(item: $editing) { g in
            GroupEditorView(group: g) {}.environmentObject(store)
        }
    }

    private var settingsSymbol: String { UserDefaults.standard.string(forKey: "set.currency") ?? "$" }
}

// MARK: - Coop Zones (Screen 23) — standalone + inline

struct CoopZonesView: View {
    @EnvironmentObject var store: FarmStore
    var body: some View {
        DetailScaffold(title: "Farm Zones") { CoopZonesInline() }
    }
}

/// Reusable zone list used both standalone and inside the Groups tab.
struct CoopZonesInline: View {
    @EnvironmentObject var store: FarmStore
    @State private var editingZone: Zone?
    @State private var showNew = false
    @State private var reorder = false
    @State private var toast: Toast?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                PillButton(title: reorder ? "Done" : "Reorder Zones",
                           icon: reorder ? "checkmark" : "arrow.up.arrow.down",
                           filled: reorder) { withAnimation(Metric.spring) { reorder.toggle() } }
                Spacer()
                PillButton(title: "Add Zone", icon: "plus", tint: Theme.amberDeep, filled: true) { showNew = true }
            }

            if store.zones.isEmpty {
                RoostCard { EmptyState(symbol: "square.dashed", title: "No zones yet",
                                       message: "Add coops, runs, a yard or a quarantine pen.") }
            } else {
                ForEach(Array(store.sortedZones.enumerated()), id: \.element.id) { idx, zone in
                    zoneRow(zone, index: idx)
                }
            }
        }
        .sheet(isPresented: $showNew) {
            ZoneEditorView(zone: nil) { toast = Toast(message: "Zone added") }.environmentObject(store)
        }
        .sheet(item: $editingZone) { z in
            ZoneEditorView(zone: z) { toast = Toast(message: "Zone saved") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func zoneRow(_ zone: Zone, index: Int) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: zone.kind.symbol, tint: Theme.wood)
                VStack(alignment: .leading, spacing: 3) {
                    Text(zone.name).font(.roost(16, .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text(zone.kind.title).font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if reorder {
                    HStack(spacing: 8) {
                        moveButton("chevron.up", enabled: index > 0) { move(zone, up: true) }
                        moveButton("chevron.down", enabled: index < store.zones.count - 1) { move(zone, up: false) }
                    }
                } else {
                    Menu {
                        Button { editingZone = zone } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.deleteZone(zone) } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 32, height: 32)
                    }
                }
            }
        }
    }

    private func moveButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? .white : Theme.textFaint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(enabled ? Theme.amber : Theme.stroke))
        }
        .disabled(!enabled)
        .buttonStyle(PressableStyle())
    }

    private func move(_ zone: Zone, up: Bool) {
        let sorted = store.sortedZones
        guard let idx = sorted.firstIndex(of: zone) else { return }
        let target = up ? idx - 1 : idx + 1
        guard target >= 0, target < sorted.count else { return }
        withAnimation(Metric.spring) {
            store.moveZones(from: IndexSet(integer: idx), to: up ? target : target + 1)
        }
    }
}

// MARK: - Zone editor

struct ZoneEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var zone: Zone?
    var onSave: () -> Void

    @State private var name = ""
    @State private var kind: ZoneKind = .coop
    @State private var notes = ""

    var body: some View {
        SheetScaffold(title: zone == nil ? "Add Zone" : "Edit Zone",
                      saveEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Zone name", placeholder: "e.g. Main Coop", text: $name, icon: "house.fill")

            Text("ZONE TYPE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ZoneKind.allCases) { k in
                    Button { withAnimation(Metric.spring) { kind = k } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: k.symbol)
                            Text(k.title).font(.roost(14, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer()
                        }
                        .padding(12).foregroundColor(kind == k ? .white : Theme.textPrimary)
                        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall)
                            .fill(kind == k ? Theme.amberGradient : Theme.card.asGradient))
                        .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: kind == k ? 0 : 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                TextEditor(text: $notes)
                    .frame(height: 90).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }
        }
        .onAppear {
            if let z = zone { name = z.name; kind = z.kind; notes = z.notes }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var z = zone {
            z.name = trimmed; z.kind = kind; z.notes = notes
            store.updateZone(z)
        } else {
            store.addZone(Zone(name: trimmed, kind: kind, notes: notes))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
