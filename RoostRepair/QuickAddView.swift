//
//  QuickAddView.swift — Screen 21: New Farm Entry
//
//  The fastest path to a record. Pick a kind, add details, link a group/zone,
//  then Save Entry (closes) or Add Another (saves & resets, sheet stays open).
//

import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode

    @State private var kind: CareLogKind = .feeding
    @State private var title = ""
    @State private var detail = ""
    @State private var groupID: UUID?
    @State private var zoneID: UUID?
    @State private var date = Date()
    @State private var toast: Toast?

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetScaffold(title: "New Farm Entry", onSave: nil,
                      onClose: { presentationMode.wrappedValue.dismiss() }) {
            label("Record type")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CareLogKind.allCases) { k in
                    Button { withAnimation(Metric.spring) { kind = k; if title.isEmpty { title = k.title } } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: k.symbol)
                            Text(k.title).font(.roost(14, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer()
                        }
                        .padding(12).foregroundColor(kind == k ? .white : Theme.textPrimary)
                        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall)
                            .fill(kind == k ? LinearGradient(colors: [k.tint, k.tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing) : Theme.card.asGradient))
                        .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: kind == k ? 0 : 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            RoostField(title: "Title", placeholder: "What happened?", text: $title, icon: kind.symbol)

            VStack(alignment: .leading, spacing: 6) {
                label("Details (optional)")
                TextEditor(text: $detail)
                    .frame(height: 80).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }

            label("Group")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: groupID == nil) { groupID = nil }
                    ForEach(store.groups) { g in
                        SelectChip(text: g.name, symbol: g.type.symbol, selected: groupID == g.id, tint: g.color) { groupID = g.id }
                    }
                }
            }

            label("Zone")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }

            DatePicker("Date & time", selection: $date)
                .font(.roostBody).accentColor(Theme.amberDeep)
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 12) {
                SecondaryButton(title: "Add Another", icon: "plus") { save(reset: true) }
                PrimaryButton(title: "Save Entry", icon: "checkmark") { save(reset: false) }
            }
            .padding(.top, 6)
            .opacity(canSave ? 1 : 0.5)
            .disabled(!canSave)
        }
        .toast($toast)
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save(reset: Bool) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.log(CareLog(kind: kind, title: trimmed, detail: detail, groupID: groupID, zoneID: zoneID, date: date))
        if reset {
            title = ""; detail = ""
            toast = Toast(message: "Saved — add another")
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
