//
//  TransportPrepView.swift — Screen 9: Transit Checklist
//
//  Prepare birds for transport: crates with counts, a transit checklist (water,
//  stops, departure) and "Confirm Load" which logs a move record.
//

import SwiftUI

struct TransportPrepView: View {
    @EnvironmentObject var store: FarmStore
    @State private var showAddCrate = false
    @State private var departure = Date()
    @State private var stops = 1
    @State private var waterPacked = false
    @State private var doorsSecure = false
    @State private var ventChecked = false
    @State private var toast: Toast?

    private var totalBirds: Int { store.crates.reduce(0) { $0 + $1.birdCount } }
    private var loadedBirds: Int { store.crates.filter { $0.loaded }.reduce(0) { $0 + $1.birdCount } }
    private var checklistReady: Bool { waterPacked && doorsSecure && ventChecked }

    var body: some View {
        DetailScaffold(title: "Transit Checklist", trailingIcon: "plus", trailingAction: { showAddCrate = true }) {
            HStack(spacing: 12) {
                StatTile(value: "\(store.crates.count)", label: "Crates", symbol: "shippingbox.fill")
                StatTile(value: "\(loadedBirds)/\(totalBirds)", label: "Loaded", symbol: "checkmark.circle.fill",
                         tint: loadedBirds == totalBirds && totalBirds > 0 ? Theme.ok : Theme.amberDeep)
            }

            SectionHeader(title: "Crates")
            if store.crates.isEmpty {
                RoostCard { EmptyState(symbol: "shippingbox", title: "No crates",
                                       message: "Add crates and confirm each is loaded.") }
            } else {
                ForEach(store.crates) { crate in crateCard(crate) }
            }
            SecondaryButton(title: "Add Crate", icon: "plus") { showAddCrate = true }

            SectionHeader(title: "Transit Prep")
            RoostCard {
                VStack(spacing: 12) {
                    DatePicker("Departure", selection: $departure)
                        .accentColor(Theme.amberDeep).foregroundColor(Theme.textPrimary)
                    RoostStepper(title: "Planned stops", value: $stops, range: 0...20)
                    Divider().background(Theme.stroke)
                    prepToggle("Water packed", "drop.fill", $waterPacked)
                    prepToggle("Crate doors secure", "lock.fill", $doorsSecure)
                    prepToggle("Ventilation checked", "wind", $ventChecked)
                }
            }

            PrimaryButton(title: "Confirm Load", icon: "checkmark.seal.fill") { confirmLoad() }
                .opacity(store.crates.isEmpty ? 0.5 : 1)
                .disabled(store.crates.isEmpty)
        }
        .sheet(isPresented: $showAddCrate) {
            CrateEditor { toast = Toast(message: "Crate added") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func crateCard(_ crate: Crate) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 14) {
                Button { store.toggleCrate(crate) } label: {
                    Image(systemName: crate.loaded ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24)).foregroundColor(crate.loaded ? Theme.ok : Theme.stroke)
                }.buttonStyle(PressableStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(crate.label).font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                    Text("\(crate.birdCount) birds\(crate.groupID != nil ? " · " + store.groupName(crate.groupID) : "")")
                        .font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Button { store.deleteCrate(crate) } label: {
                    Image(systemName: "trash").foregroundColor(Theme.danger).frame(width: 28, height: 28)
                }
            }
        }
    }

    private func prepToggle(_ title: String, _ symbol: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: symbol).font(.roostBody).foregroundColor(Theme.textPrimary)
        }.toggleStyle(SwitchToggleStyle(tint: Theme.amber))
    }

    private func confirmLoad() {
        // Mark all crates loaded.
        for crate in store.crates where !crate.loaded { store.toggleCrate(crate) }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .short
        let detail = "\(store.crates.count) crates · \(totalBirds) birds · depart \(f.string(from: departure)) · \(stops) stop(s)\(checklistReady ? " · prep ✓" : "")"
        store.log(CareLog(kind: .move, title: "Transport load confirmed", detail: detail))
        toast = Toast(message: "Load confirmed & logged")
    }
}

// MARK: - Crate editor

struct CrateEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var onSave: () -> Void

    @State private var label = ""
    @State private var count = 4
    @State private var groupID: UUID?

    var body: some View {
        SheetScaffold(title: "Add Crate",
                      saveEnabled: !label.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Crate label", placeholder: "e.g. Crate A", text: $label, icon: "shippingbox.fill")
            RoostStepper(title: "Birds in crate", value: $count, range: 1...100)
            Text("GROUP (optional)").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: groupID == nil) { groupID = nil }
                    ForEach(store.groups) { g in
                        SelectChip(text: g.name, symbol: g.type.symbol, selected: groupID == g.id, tint: g.color) { groupID = g.id }
                    }
                }
            }
        }
    }
    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addCrate(Crate(label: trimmed, birdCount: count, groupID: groupID))
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
