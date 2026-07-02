//
//  WaterLogView.swift — Screen 5: Water & Heat Notes
//
//  Log water, temperature, ventilation and waterer condition. "Add Alert" raises
//  a high-priority task for an early warning. Recent water checks are listed.
//

import SwiftUI

struct WaterLogView: View {
    @EnvironmentObject var store: FarmStore
    @State private var showCheck = false
    @State private var showAlert = false
    @State private var toast: Toast?

    private var waterLogs: [CareLog] { store.logs.filter { $0.kind == .water } }

    var body: some View {
        DetailScaffold(title: "Water & Heat Notes") {
            HStack(spacing: 12) {
                StatTile(value: "\(waterLogs.count)", label: "Water checks", symbol: "drop.fill", tint: Theme.info)
                StatTile(value: "\(store.logs.filter { Calendar.current.isDateInToday($0.date) && $0.kind == .water }.count)",
                         label: "Today", symbol: "calendar", tint: Theme.amberDeep)
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Log Check", icon: "drop.fill") { showCheck = true }
                SecondaryButton(title: "Add Alert", icon: "exclamationmark.triangle.fill") { showAlert = true }
            }

            SectionHeader(title: "Recent Checks")
            if waterLogs.isEmpty {
                RoostCard { EmptyState(symbol: "drop", title: "No water checks",
                                       message: "Log water, heat and ventilation notes here.") }
            } else {
                ForEach(waterLogs.prefix(12)) { log in
                    RoostCard(padding: 14) {
                        HStack(spacing: 14) {
                            IconBadge(symbol: "drop.fill", tint: Theme.info)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                if !log.detail.isEmpty {
                                    Text(log.detail).font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(2)
                                }
                                Text("\(store.zoneName(log.zoneID)) · \(FarmStore.shortDate(log.date))")
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
        .sheet(isPresented: $showCheck) {
            WaterCheckEditor { toast = Toast(message: "Water check logged") }.environmentObject(store)
        }
        .sheet(isPresented: $showAlert) {
            WaterAlertEditor { toast = Toast(message: "Alert task created", symbol: "exclamationmark.triangle.fill") }.environmentObject(store)
        }
        .toast($toast)
    }
}

// MARK: - Water check editor

struct WaterCheckEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var onSave: () -> Void

    @State private var zoneID: UUID?
    @State private var temperature: Double = 18
    @State private var waterOK = true
    @State private var ventOK = true
    @State private var note = ""

    var body: some View {
        SheetScaffold(title: "Log Water Check", onSave: save,
                      onClose: { presentationMode.wrappedValue.dismiss() }) {
            Text("ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TEMPERATURE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                    Spacer()
                    Text("\(Int(temperature))°").font(.roost(13, .bold)).foregroundColor(Theme.amberDeep)
                }
                Slider(value: $temperature, in: -10...45, step: 1).accentColor(Theme.amber)
            }

            Toggle(isOn: $waterOK) { Label("Waterers clean & full", systemImage: "drop.fill").font(.roostBody).foregroundColor(Theme.textPrimary) }
                .toggleStyle(SwitchToggleStyle(tint: Theme.amber))
            Toggle(isOn: $ventOK) { Label("Ventilation good", systemImage: "wind").font(.roostBody).foregroundColor(Theme.textPrimary) }
                .toggleStyle(SwitchToggleStyle(tint: Theme.amber))

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                TextEditor(text: $note).frame(height: 70).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }
        }
    }

    private func save() {
        var parts = ["\(Int(temperature))°"]
        parts.append(waterOK ? "water OK" : "water LOW")
        parts.append(ventOK ? "vent OK" : "vent POOR")
        if !note.isEmpty { parts.append(note) }
        store.log(CareLog(kind: .water, title: "Water check", detail: parts.joined(separator: " · "), zoneID: zoneID))
        // A failing check also raises a flag-worthy task.
        if !waterOK || !ventOK {
            store.addTask(FarmTask(title: "Check waterers / ventilation", detail: parts.joined(separator: " · "),
                                   priority: .high, zoneID: zoneID, dueDate: Date()))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Water alert editor

struct WaterAlertEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var onSave: () -> Void

    @State private var title = "Water alert"
    @State private var zoneID: UUID?
    @State private var detail = ""

    var body: some View {
        SheetScaffold(title: "Add Alert",
                      saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Alert", placeholder: "e.g. Frozen waterer", text: $title, icon: "exclamationmark.triangle.fill")
            Text("ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("DETAIL").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                TextEditor(text: $detail).frame(height: 80).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }
            Text("Creates a high-priority task and a water record.")
                .font(.roostCaption).foregroundColor(Theme.textFaint)
        }
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addTask(FarmTask(title: trimmed, detail: detail, priority: .high, zoneID: zoneID, dueDate: Date()))
        store.log(CareLog(kind: .water, title: "⚠︎ \(trimmed)", detail: detail, zoneID: zoneID))
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
