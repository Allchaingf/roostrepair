//
//  ReportBuilderView.swift — Screen 20: Farm Report
//
//  Assemble a report over a chosen period (records, costs, tasks, alerts,
//  inventory), preview it, then export a real PDF via the share sheet.
//

import SwiftUI
import UIKit

struct ReportBuilderView: View {
    @EnvironmentObject var store: FarmStore
    @EnvironmentObject var settings: AppSettings

    @State private var days = 7
    @State private var includeRecords = true
    @State private var includeCosts = true
    @State private var includeTasks = true
    @State private var includeAlerts = true
    @State private var includeInventory = false
    @State private var reportText: String?
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var toast: Toast?

    private var sym: String { settings.currencySymbol }

    var body: some View {
        DetailScaffold(title: "Farm Report") {
            RoostCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PERIOD").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                    HStack(spacing: 8) {
                        ForEach([7, 30, 90], id: \.self) { d in
                            SelectChip(text: d == 7 ? "Week" : (d == 30 ? "Month" : "Quarter"),
                                       selected: days == d) { days = d; reportText = nil }
                        }
                    }
                    Divider().background(Theme.stroke)
                    Text("INCLUDE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                    includeToggle("Care records", "note.text", $includeRecords)
                    includeToggle("Costs", "dollarsign.circle", $includeCosts)
                    includeToggle("Tasks", "checkmark.square", $includeTasks)
                    includeToggle("Alerts", "flag", $includeAlerts)
                    includeToggle("Inventory", "shippingbox", $includeInventory)
                }
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Generate Report", icon: "doc.text.magnifyingglass") { generate() }
                if reportText != nil {
                    SecondaryButton(title: "Export PDF", icon: "square.and.arrow.up") { exportPDF() }
                }
            }

            if let text = reportText {
                RoostCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IconBadge(symbol: "doc.text.fill", tint: Theme.amberDeep, size: 36)
                            Text("Report Preview").font(.roost(16, .bold)).foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        Divider().background(Theme.stroke)
                        Text(text).font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .toast($toast)
    }

    private func includeToggle(_ title: String, _ symbol: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: symbol).font(.roostBody).foregroundColor(Theme.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.amber))
        .onChange(of: binding.wrappedValue) { _ in reportText = nil }
    }

    // MARK: Build report text
    private func generate() {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let df = DateFormatter(); df.dateStyle = .medium

        var lines: [String] = []
        lines.append("ROOST REPAIR — FARM REPORT")
        lines.append("Period: last \(days) days")
        lines.append("Generated: \(df.string(from: Date()))")
        lines.append(String(repeating: "─", count: 34))
        lines.append("Flock: \(store.groups.count) groups · \(store.totalBirds) birds · \(store.zones.count) zones")
        lines.append("")

        if includeRecords {
            let recs = store.logs.filter { $0.date >= cutoff }
            lines.append("CARE RECORDS (\(recs.count))")
            for (kind, count) in store.logsByKind(days: days) {
                lines.append("  • \(kind.title): \(count)")
            }
            lines.append("  Consistency: \(Int(store.weeklyConsistency * 100))%")
            lines.append("")
        }
        if includeCosts {
            let costs = store.costs.filter { $0.date >= cutoff }
            let total = costs.reduce(0) { $0 + $1.amount }
            lines.append("COSTS (\(total.money(sym)))")
            for (cat, value) in store.costByCategory(days: days) {
                lines.append("  • \(cat.title): \(value.money(sym))")
            }
            lines.append("")
        }
        if includeTasks {
            lines.append("TASKS")
            lines.append("  Open: \(store.openTasks.count) · Overdue: \(store.tasks.filter { $0.isOverdue }.count) · Done: \(store.tasks.filter { $0.done }.count)")
            for t in store.openTasks.prefix(8) {
                lines.append("  • [\(t.priority.title)] \(t.title)")
            }
            lines.append("")
        }
        if includeAlerts {
            let flags = store.riskFlags
            lines.append("ALERTS (\(flags.count))")
            for f in flags.prefix(10) { lines.append("  • [\(f.severity.title)] \(f.title)") }
            if flags.isEmpty { lines.append("  • None — all clear") }
            lines.append("")
        }
        if includeInventory {
            lines.append("INVENTORY (\(store.inventory.count) items, \(store.lowStock.count) low)")
            for i in store.inventory {
                lines.append("  • \(i.name): \(i.quantity.clean) \(i.unit)\(i.isLow ? " (LOW)" : "")")
            }
            lines.append("")
        }
        lines.append(String(repeating: "─", count: 34))
        lines.append("Generated offline by Roost Repair.")

        withAnimation(Metric.spring) { reportText = lines.joined(separator: "\n") }
        toast = Toast(message: "Report generated")
    }

    // MARK: Export to PDF
    private func exportPDF() {
        guard let text = reportText else { return }
        let pageW: CGFloat = 612, pageH: CGFloat = 792
        let margin: CGFloat = 44
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let bodyFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let amber = UIColor(rgb: 0xCE7C24)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RoostReport.pdf")
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                // Header band
                amber.setFill()
                ctx.cgContext.fill(CGRect(x: 0, y: 0, width: pageW, height: 70))
                ("Roost Repair" as NSString).draw(
                    at: CGPoint(x: margin, y: 24),
                    withAttributes: [.font: titleFont, .foregroundColor: UIColor.white])

                // Body, paginated by line.
                var y: CGFloat = 92
                let lineHeight: CGFloat = 15
                for line in text.components(separatedBy: "\n") {
                    if y > pageH - margin {
                        ctx.beginPage(); y = margin
                    }
                    (line as NSString).draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: [.font: bodyFont, .foregroundColor: UIColor(rgb: 0x2E2114)])
                    y += lineHeight
                }
            }
            shareURL = url
            showShare = true
        } catch {
            toast = Toast(message: "Export failed", symbol: "exclamationmark.triangle.fill")
        }
    }
}
