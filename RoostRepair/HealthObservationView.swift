//
//  HealthObservationView.swift — Screen 6: Observation Log
//
//  Plain observations (activity, appetite, appearance) — no medical diagnoses.
//  "Add Symptom" logs an observation; "Flag Group" marks a group for re-check.
//

import SwiftUI

struct HealthObservationView: View {
    @EnvironmentObject var store: FarmStore
    @State private var showAdd = false
    @State private var showFlag = false
    @State private var toast: Toast?

    private var healthLogs: [CareLog] { store.logs.filter { $0.kind == .health } }
    private var flagged: [BirdGroup] { store.groups.filter { $0.flagged } }

    var body: some View {
        DetailScaffold(title: "Observation Log") {
            HStack(spacing: 12) {
                StatTile(value: "\(healthLogs.count)", label: "Observations", symbol: "stethoscope", tint: Theme.barnRed)
                StatTile(value: "\(flagged.count)", label: "Flagged", symbol: "flag.fill",
                         tint: flagged.isEmpty ? Theme.ok : Theme.danger)
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Add Symptom", icon: "plus.circle.fill") { showAdd = true }
                SecondaryButton(title: "Flag Group", icon: "flag.fill") { showFlag = true }
            }

            if !flagged.isEmpty {
                SectionHeader(title: "Flagged for re-check")
                ForEach(flagged) { g in
                    RoostCard(padding: 14) {
                        HStack(spacing: 12) {
                            IconBadge(symbol: "flag.fill", tint: Theme.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.name).font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                                Text("\(g.count) \(g.type.title.lowercased()) · \(store.zoneName(g.zoneID))")
                                    .font(.roostCaption).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Button { store.toggleGroupFlag(g); toast = Toast(message: "Flag cleared") } label: {
                                Text("Resolve").font(.roost(13, .semibold)).foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Theme.ok))
                            }.buttonStyle(PressableStyle())
                        }
                    }
                }
            }

            SectionHeader(title: "Recent Observations")
            if healthLogs.isEmpty {
                RoostCard { EmptyState(symbol: "eye", title: "No observations",
                                       message: "Note activity, appetite and appearance — no diagnoses needed.") }
            } else {
                ForEach(healthLogs.prefix(12)) { log in
                    RoostCard(padding: 14) {
                        HStack(spacing: 14) {
                            IconBadge(symbol: "stethoscope", tint: Theme.barnRed)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                if !log.detail.isEmpty {
                                    Text(log.detail).font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(2)
                                }
                                Text("\(store.groupName(log.groupID)) · \(FarmStore.shortDate(log.date))")
                                    .font(.roost(11, .medium)).foregroundColor(Theme.textFaint)
                            }
                            Spacer()
                            Button { store.deleteLog(log) } label: {
                                Image(systemName: "trash").foregroundColor(Theme.danger).frame(width: 28, height: 28)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            SymptomEditor { toast = Toast(message: "Observation logged") }.environmentObject(store)
        }
        .sheet(isPresented: $showFlag) {
            FlagGroupSheet { toast = Toast(message: "Group flagged") }.environmentObject(store)
        }
        .toast($toast)
    }
}

// MARK: - Symptom editor

struct SymptomEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var onSave: () -> Void

    private let signs = ["Low activity", "Reduced appetite", "Ruffled feathers", "Isolated", "Limping", "Watery eyes", "Sneezing", "Pale comb"]
    @State private var groupID: UUID?
    @State private var selected: Set<String> = []
    @State private var note = ""
    @State private var flagAfter = false

    var body: some View {
        SheetScaffold(title: "Add Symptom",
                      saveEnabled: !selected.isEmpty || !note.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            Text("GROUP").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: groupID == nil) { groupID = nil }
                    ForEach(store.groups) { g in
                        SelectChip(text: g.name, symbol: g.type.symbol, selected: groupID == g.id, tint: g.color) { groupID = g.id }
                    }
                }
            }

            Text("OBSERVED SIGNS").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            FlowChips(items: signs, selected: $selected)

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                TextEditor(text: $note).frame(height: 80).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }

            Toggle(isOn: $flagAfter) {
                Label("Flag this group for re-check", systemImage: "flag.fill").font(.roostBody).foregroundColor(Theme.textPrimary)
            }.toggleStyle(SwitchToggleStyle(tint: Theme.amber))
        }
    }
    private func save() {
        let title = selected.isEmpty ? "Observation" : selected.sorted().joined(separator: ", ")
        store.log(CareLog(kind: .health, title: title, detail: note, groupID: groupID,
                          zoneID: store.group(groupID)?.zoneID))
        if flagAfter, let id = groupID, let g = store.group(id), !g.flagged { store.toggleGroupFlag(g) }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Flag group sheet

struct FlagGroupSheet: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var onSave: () -> Void

    var body: some View {
        SheetScaffold(title: "Flag Group", onSave: nil,
                      onClose: { presentationMode.wrappedValue.dismiss() }) {
            Text("Tap a group to toggle its re-check flag.")
                .font(.roostBody).foregroundColor(Theme.textSecondary)
            if store.groups.isEmpty {
                EmptyState(symbol: "oval.fill", title: "No groups", message: "Create a group first.")
            } else {
                ForEach(store.groups) { g in
                    Button { store.toggleGroupFlag(g); onSave() } label: {
                        HStack(spacing: 12) {
                            IconBadge(symbol: g.type.symbol, tint: g.color)
                            Text(g.name).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Image(systemName: g.flagged ? "flag.fill" : "flag")
                                .foregroundColor(g.flagged ? Theme.danger : Theme.stroke).font(.system(size: 18))
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(Theme.stroke, lineWidth: 1))
                    }.buttonStyle(PressableStyle())
                }
            }
        }
    }
}

// MARK: - Flow chips (wrapping selectable tags)

struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        // Simple two-column wrap that works on iOS 14.
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items, id: \.self) { item in
                SelectChip(text: item, selected: selected.contains(item)) {
                    if selected.contains(item) { selected.remove(item) } else { selected.insert(item) }
                }
            }
        }
    }
}
