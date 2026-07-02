//
//  Charts.swift
//  RoostRepair
//
//  Lightweight custom charts built from Shapes/Paths so they run on iOS 14
//  (no Swift Charts dependency). Bar chart, line chart and horizontal bars.
//

import SwiftUI

// MARK: - Vertical bar chart

struct BarChart: View {
    /// (label, value, tint)
    var data: [(String, Double, Color)]
    var height: CGFloat = 150

    private var maxValue: Double { max(data.map { $0.1 }.max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 6) {
                    Text(item.1 > 0 ? item.1.clean : "")
                        .font(.roost(10, .bold)).foregroundColor(Theme.textSecondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [item.2, item.2.opacity(0.6)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(4, CGFloat(item.1 / maxValue) * height))
                    Text(item.0).font(.roost(10, .semibold)).foregroundColor(Theme.textFaint)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 34)
        .animation(Metric.softSpring, value: maxValue)
    }
}

// MARK: - Line chart (with gradient fill)

struct LineChart: View {
    var values: [Double]
    var labels: [String]
    var tint: Color = Theme.amber
    var height: CGFloat = 150

    private var maxValue: Double { max(values.max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let step = values.count > 1 ? w / CGFloat(values.count - 1) : w
                ZStack {
                    // Fill
                    Path { p in
                        guard !values.isEmpty else { return }
                        p.move(to: CGPoint(x: 0, y: h))
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * step
                            let y = h - CGFloat(v / maxValue) * h
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    // Stroke
                    Path { p in
                        guard !values.isEmpty else { return }
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * step
                            let y = h - CGFloat(v / maxValue) * h
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    // Points
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        Circle().fill(tint)
                            .frame(width: 7, height: 7)
                            .position(x: CGFloat(i) * step,
                                      y: h - CGFloat(v / maxValue) * h)
                    }
                }
            }
            .frame(height: height)

            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { _, l in
                    Text(l).font(.roost(10, .semibold)).foregroundColor(Theme.textFaint)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Horizontal bar (category breakdown)

struct HBar: View {
    var label: String
    var value: Double
    var maxValue: Double
    var tint: Color
    var valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.roost(13, .semibold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Text(valueText).font(.roost(13, .bold)).foregroundColor(Theme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.stroke.opacity(0.6)).frame(height: 10)
                    Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.65)],
                                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * CGFloat(maxValue > 0 ? value / maxValue : 0)), height: 10)
                        .animation(Metric.softSpring, value: value)
                }
            }
            .frame(height: 10)
        }
    }
}
