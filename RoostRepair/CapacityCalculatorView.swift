//
//  CapacityCalculatorView.swift — Screen 2: Space & Perch Capacity
//
//  Enter floor area, perch length, bird count and a space buffer to estimate
//  how loaded a zone is. Results can be saved; an overloaded result becomes a
//  risk flag on the dashboard.
//

import SwiftUI

struct CapacityCalculatorView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings

    @State private var area: Double = 0
    @State private var perch: Double = 0
    @State private var birds: Int = 0
    @State private var buffer: Double = 15
    @State private var zoneID: UUID?
    @State private var result: CapacityResult?
    @State private var toast: Toast?

    var body: some View {
        DetailScaffold(title: "Space & Perch Capacity") {
            RoostCard {
                VStack(spacing: 14) {
                    RoostNumberField(title: "Floor area (\(settings.measureSystem.areaUnit))", value: $area, icon: "square.dashed")
                    RoostNumberField(title: "Perch length (\(settings.measureSystem.lengthUnit))", value: $perch, icon: "ruler")
                    RoostStepper(title: "Number of birds", value: $birds, range: 0...5000)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SPACE BUFFER").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                            Spacer()
                            Text("\(Int(buffer))%").font(.roost(13, .bold)).foregroundColor(Theme.amberDeep)
                        }
                        Slider(value: $buffer, in: 0...50, step: 5).accentColor(Theme.amber)
                    }
                    fieldLabel("Zone (optional)")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                            ForEach(store.sortedZones) { z in
                                SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Calculate", icon: "gauge") { calculate() }
                if result != nil {
                    SecondaryButton(title: "Save Result", icon: "tray.and.arrow.down.fill") { saveResult() }
                }
            }

            if let r = result { resultCard(r) }

            if !store.capacityResults.isEmpty {
                SectionHeader(title: "Saved Results")
                ForEach(store.capacityResults) { saved in
                    RoostCard(padding: 14) {
                        HStack(spacing: 14) {
                            ProgressRing(progress: saved.load, size: 50, lineWidth: 7, tint: loadColor(saved.load))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(saved.zoneName.isEmpty ? "Capacity check" : saved.zoneName)
                                    .font(.roost(15, .bold)).foregroundColor(Theme.textPrimary)
                                Text(saved.verdict).font(.roostCaption).foregroundColor(Theme.textSecondary)
                                Text("\(saved.birds) birds · \(FarmStore.shortDate(saved.date))").font(.roost(11, .medium)).foregroundColor(Theme.textFaint)
                            }
                            Spacer()
                            Button { store.deleteCapacity(saved) } label: {
                                Image(systemName: "trash").foregroundColor(Theme.danger).frame(width: 32, height: 32)
                            }
                        }
                    }
                }
            }
        }
        .toast($toast)
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultCard(_ r: CapacityResult) -> some View {
        RoostCard {
            VStack(spacing: 14) {
                HStack(spacing: 18) {
                    ProgressRing(progress: r.load, size: 84, lineWidth: 11, tint: loadColor(r.load))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(r.verdict).font(.roost(18, .bold)).foregroundColor(loadColor(r.load))
                        Text("Estimated load \(Int(r.load * 100))%").font(.roostBody).foregroundColor(Theme.textPrimary)
                        Text(recommendation(r.load)).font(.roostCaption).foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
        }
    }

    private func loadColor(_ load: Double) -> Color {
        load > 1 ? Theme.danger : (load > 0.85 ? Theme.warn : Theme.ok)
    }
    private func recommendation(_ load: Double) -> String {
        if load > 1 { return "Overloaded — add space, split the group, or extend the perch." }
        if load > 0.85 { return "Near capacity — watch for crowding and wear on doors & mesh." }
        return "Comfortable — good room for the flock."
    }

    private func calculate() {
        // Normalise to metric for the comparison.
        let metric = settings.measureSystem == .metric
        let areaM2 = metric ? area : area * 0.092903
        let perchCM = metric ? perch : perch * 2.54
        let spacePerBird = 0.37     // m² per chicken (sensible default)
        let perchPerBird = 20.0     // cm per bird

        let neededArea = Double(birds) * spacePerBird * (1 + buffer / 100)
        let areaLoad = areaM2 > 0 ? neededArea / areaM2 : (birds > 0 ? 2 : 0)

        let neededPerch = Double(birds) * perchPerBird
        let perchLoad = perchCM > 0 ? neededPerch / perchCM : 0

        let load = max(areaLoad, perchLoad)
        let verdict = load > 1 ? "Overloaded" : (load > 0.85 ? "Near capacity" : "Comfortable")

        withAnimation(Metric.softSpring) {
            result = CapacityResult(area: area, perchLength: perch, birds: birds, buffer: buffer,
                                    zoneName: store.zone(zoneID)?.name ?? "",
                                    load: min(load, 1.4), verdict: verdict)
        }
    }

    private func saveResult() {
        guard let r = result else { return }
        store.addCapacity(r)
        toast = Toast(message: "Result saved")
    }
}
