//
//  RiskFlagsView.swift — Screen 16: Farm Alerts
//
//  Collects risks from overdue tasks, overdue cleaning, low stock, flagged
//  groups and zone overload. Resolve individual flags or restore resolved ones.
//

import SwiftUI

struct RiskFlagsView: View {
    @EnvironmentObject var store: FarmStore
    @State private var filter: RiskFlag.Severity?
    @State private var toast: Toast?

    private var flags: [RiskFlag] {
        guard let f = filter else { return store.riskFlags }
        return store.riskFlags.filter { $0.severity == f }
    }

    var body: some View {
        DetailScaffold(title: "Farm Alerts") {
            HStack(spacing: 12) {
                severityTile(.high, count: store.riskFlags.filter { $0.severity == .high }.count)
                severityTile(.warn, count: store.riskFlags.filter { $0.severity == .warn }.count)
                severityTile(.info, count: store.riskFlags.filter { $0.severity == .info }.count)
            }

            HStack(spacing: 8) {
                SelectChip(text: "Review Flags", symbol: "list.bullet", selected: filter == nil) { filter = nil }
                ForEach([RiskFlag.Severity.high, .warn, .info], id: \.rawValue) { sev in
                    SelectChip(text: sev.title, selected: filter == sev, tint: sev.tint) {
                        filter = filter == sev ? nil : sev
                    }
                }
            }

            if flags.isEmpty {
                RoostCard {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "checkmark.seal.fill", tint: Theme.ok, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("All clear").font(.roost(17, .bold)).foregroundColor(Theme.textPrimary)
                            Text("No active alerts. Nice and tidy!").font(.roostCaption).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
            } else {
                ForEach(flags) { flag in flagCard(flag) }
                SecondaryButton(title: "Resolve All Shown", icon: "checkmark.circle.fill") {
                    withAnimation(Metric.spring) { flags.forEach { store.resolveFlag($0) } }
                    toast = Toast(message: "Alerts resolved")
                }
            }

            if !store.resolvedFlags.isEmpty {
                Button { store.clearResolved(); toast = Toast(message: "Resolved alerts restored") } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore \(store.resolvedFlags.count) resolved").font(.roost(14, .semibold))
                        Spacer()
                    }
                    .foregroundColor(Theme.textSecondary).padding(.top, 4)
                }
            }
        }
        .toast($toast)
    }

    private func severityTile(_ sev: RiskFlag.Severity, count: Int) -> some View {
        RoostCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                IconBadge(symbol: sev == .high ? "exclamationmark.triangle.fill" : (sev == .warn ? "exclamationmark.circle.fill" : "info.circle.fill"),
                          tint: sev.tint, size: 34)
                Text("\(count)").font(.roost(22, .bold)).foregroundColor(Theme.textPrimary)
                Text(sev.title).font(.roostCaption).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func flagCard(_ flag: RiskFlag) -> some View {
        RoostCard(padding: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: flag.symbol, tint: flag.severity.tint, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(flag.title).font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(2)
                    Text(flag.detail).font(.roostCaption).foregroundColor(Theme.textSecondary).lineLimit(2)
                }
                Spacer()
                Button { withAnimation(Metric.spring) { store.resolveFlag(flag) }; toast = Toast(message: "Resolved") } label: {
                    Text("Resolve").font(.roost(13, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.ok))
                }.buttonStyle(PressableStyle())
            }
        }
    }
}
