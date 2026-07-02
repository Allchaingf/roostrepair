//
//  RoutePlannerView.swift — Screen 8: Care Route
//
//  Build an ordered walking round across zones with an estimated time, then
//  "Start Round" to check off each stop. Finishing logs a record.
//

import SwiftUI

struct RoutePlannerView: View {
    @EnvironmentObject var store: FarmStore
    @State private var roundMode = false
    @State private var showAddStop = false
    @State private var toast: Toast?

    private var route: CareRoute? { store.routes.first }

    var body: some View {
        DetailScaffold(title: "Care Route") {
            if let route = route {
                RoostCard {
                    HStack(spacing: 16) {
                        IconBadge(symbol: "map.fill", tint: Theme.amberDeep, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(route.name).font(.roost(18, .bold)).foregroundColor(Theme.textPrimary)
                            Text("\(route.stops.count) stops · ~\(route.totalMinutes) min").font(.roostCaption).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }

                if roundMode {
                    let done = route.stops.filter { $0.checked }.count
                    RoostCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Round in progress").font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(done)/\(route.stops.count)").font(.roost(14, .bold)).foregroundColor(Theme.amberDeep)
                            }
                            ProgressView(value: Double(done), total: Double(max(route.stops.count, 1)))
                                .accentColor(Theme.amber)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if roundMode {
                        PrimaryButton(title: "Finish Round", icon: "flag.fill") { finishRound(route) }
                        SecondaryButton(title: "Add Stop", icon: "plus") { showAddStop = true }
                    } else {
                        PrimaryButton(title: "Start Round", icon: "play.fill") { startRound(route) }
                        SecondaryButton(title: "Add Stop", icon: "plus") { showAddStop = true }
                    }
                }

                if route.stops.isEmpty {
                    RoostCard { EmptyState(symbol: "point.topleft.down.curvedto.point.bottomright.up",
                                           title: "No stops yet", message: "Add zones to build your round.") }
                } else {
                    ForEach(Array(route.stops.enumerated()), id: \.element.id) { idx, stop in
                        stopRow(route: route, stop: stop, index: idx)
                    }
                }
            } else {
                RoostCard { EmptyState(symbol: "map", title: "No route yet",
                                       message: "Build a care route to organise your daily round.") }
                PrimaryButton(title: "Build Route", icon: "plus.circle.fill") { buildRoute() }
            }
        }
        .sheet(isPresented: $showAddStop) {
            RouteStopEditor { label, zoneID, minutes in addStop(label: label, zoneID: zoneID, minutes: minutes) }
                .environmentObject(store)
        }
        .toast($toast)
    }

    private func stopRow(route: CareRoute, stop: RouteStop, index: Int) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 12) {
                if roundMode {
                    Button { toggleStop(route, stop) } label: {
                        Image(systemName: stop.checked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24)).foregroundColor(stop.checked ? Theme.ok : Theme.stroke)
                    }.buttonStyle(PressableStyle())
                } else {
                    Text("\(index + 1)").font(.roost(13, .bold)).foregroundColor(.white)
                        .frame(width: 28, height: 28).background(Circle().fill(Theme.amber))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.label).font(.roost(15, .semibold))
                        .foregroundColor(stop.checked && roundMode ? Theme.textFaint : Theme.textPrimary)
                        .strikethrough(stop.checked && roundMode, color: Theme.textFaint).lineLimit(1)
                    Text("\(store.zoneName(stop.zoneID)) · \(stop.minutes) min").font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if !roundMode {
                    HStack(spacing: 6) {
                        moveBtn("chevron.up", enabled: index > 0) { move(route, index, up: true) }
                        moveBtn("chevron.down", enabled: index < route.stops.count - 1) { move(route, index, up: false) }
                        Button { deleteStop(route, stop) } label: {
                            Image(systemName: "trash").foregroundColor(Theme.danger).frame(width: 28, height: 28)
                        }
                    }
                }
            }
        }
    }

    private func moveBtn(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                .foregroundColor(enabled ? .white : Theme.textFaint)
                .frame(width: 28, height: 28).background(Circle().fill(enabled ? Theme.amber : Theme.stroke))
        }.disabled(!enabled).buttonStyle(PressableStyle())
    }

    // MARK: Actions
    private func buildRoute() {
        store.addRoute(CareRoute(name: "Daily Round"))
        toast = Toast(message: "Route created")
    }
    private func addStop(label: String, zoneID: UUID?, minutes: Int) {
        guard var r = route else { return }
        r.stops.append(RouteStop(zoneID: zoneID, label: label, minutes: minutes))
        store.updateRoute(r)
        toast = Toast(message: "Stop added")
    }
    private func deleteStop(_ route: CareRoute, _ stop: RouteStop) {
        var r = route; r.stops.removeAll { $0.id == stop.id }; store.updateRoute(r)
    }
    private func move(_ route: CareRoute, _ index: Int, up: Bool) {
        var r = route
        let target = up ? index - 1 : index + 1
        guard target >= 0, target < r.stops.count else { return }
        withAnimation(Metric.spring) { r.stops.swapAt(index, target) }
        store.updateRoute(r)
    }
    private func toggleStop(_ route: CareRoute, _ stop: RouteStop) {
        var r = route
        if let i = r.stops.firstIndex(where: { $0.id == stop.id }) {
            withAnimation(Metric.spring) { r.stops[i].checked.toggle() }
            store.updateRoute(r)
        }
    }
    private func startRound(_ route: CareRoute) {
        var r = route
        for i in r.stops.indices { r.stops[i].checked = false }
        store.updateRoute(r)
        withAnimation(Metric.spring) { roundMode = true }
    }
    private func finishRound(_ route: CareRoute) {
        let done = route.stops.filter { $0.checked }.count
        store.log(CareLog(kind: .note, title: "Care round done", detail: "\(done)/\(route.stops.count) stops · ~\(route.totalMinutes) min"))
        var r = route
        for i in r.stops.indices { r.stops[i].checked = false }
        store.updateRoute(r)
        withAnimation(Metric.spring) { roundMode = false }
        toast = Toast(message: "Round logged")
    }
}

// MARK: - Route stop editor

struct RouteStopEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var onSave: (String, UUID?, Int) -> Void

    @State private var label = ""
    @State private var zoneID: UUID?
    @State private var minutes = 5

    var body: some View {
        SheetScaffold(title: "Add Stop",
                      saveEnabled: !label.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "What to do", placeholder: "e.g. Open coop & feed", text: $label, icon: "list.bullet")
            Text("ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }
            RoostStepper(title: "Minutes", value: $minutes, range: 1...120)
        }
    }
    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, zoneID, minutes)
        presentationMode.wrappedValue.dismiss()
    }
}
