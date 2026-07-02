//
//  Components.swift
//  RoostRepair
//
//  The custom component library — cards, buttons, fields, chips, stat tiles,
//  progress rings, empty states and the shared screen scaffold. Used everywhere
//  so the whole app shares one warm, coop-themed look.
//

import SwiftUI

// MARK: - Press feedback

/// Scales + softens a control while pressed for tactile feedback.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Metric.spring, value: configuration.isPressed)
    }
}

// MARK: - Card

struct RoostCard<Content: View>: View {
    var padding: CGFloat = Metric.pad
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon) }
                Text(title).font(.roost(17, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                    .fill(Theme.amberGradient)
            )
            .shadow(color: Theme.amberDeep.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecondaryButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon) }
                Text(title).font(.roost(17, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundColor(Theme.amberDeep)
            .background(
                RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                    .fill(Theme.amberSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                    .stroke(Theme.amber.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

/// A compact pill button for inline actions.
struct PillButton: View {
    var title: String
    var icon: String? = nil
    var tint: Color = Theme.amberDeep
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.roost(14, .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundColor(filled ? .white : tint)
            .background(
                Capsule().fill(filled ? tint : tint.opacity(0.14))
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Circular icon badge

struct IconBadge: View {
    var symbol: String
    var tint: Color = Theme.amber
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.16)))
    }
}

// MARK: - Input fields

struct RoostField: View {
    var title: String
    var placeholder: String = ""
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            }
            HStack(spacing: 10) {
                if let icon = icon { Image(systemName: icon).foregroundColor(Theme.amberDeep) }
                TextField(placeholder, text: $text)
                    .font(.roostBody)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

struct RoostNumberField: View {
    var title: String
    @Binding var value: Double
    var unit: String = ""
    var icon: String? = nil

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title.uppercased()).font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            }
            HStack(spacing: 10) {
                if let icon = icon { Image(systemName: icon).foregroundColor(Theme.amberDeep) }
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.roostBody)
                    .foregroundColor(Theme.textPrimary)
                    .onChange(of: text) { new in
                        value = Double(new.replacingOccurrences(of: ",", with: ".")) ?? 0
                    }
                if !unit.isEmpty { Text(unit).font(.roostCaption).foregroundColor(Theme.textFaint) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
        }
        .onAppear { if value != 0 { text = value.clean } }
    }
}

// MARK: - Stepper field for integer counts

struct RoostStepper: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...9999

    var body: some View {
        HStack {
            Text(title).font(.roostBody).foregroundColor(Theme.textPrimary)
            Spacer()
            HStack(spacing: 16) {
                stepButton("minus") { if value > range.lowerBound { value -= 1 } }
                Text("\(value)").font(.roost(18, .bold)).foregroundColor(Theme.amberDeep)
                    .frame(minWidth: 34)
                stepButton("plus") { if value < range.upperBound { value += 1 } }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(Metric.spring) { action() } }) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.amber))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.roost(18, .bold)).foregroundColor(Theme.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle).font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle).font(.roost(14, .semibold)).foregroundColor(Theme.amberDeep)
                }
            }
        }
    }
}

// MARK: - Chips & tags

struct TagChip: View {
    var text: String
    var symbol: String? = nil
    var tint: Color = Theme.wood

    var body: some View {
        HStack(spacing: 5) {
            if let symbol = symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.roost(12, .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundColor(tint)
        .background(Capsule().fill(tint.opacity(0.15)))
    }
}

/// Selectable chip used in filters / pickers.
struct SelectChip: View {
    var text: String
    var symbol: String? = nil
    var selected: Bool
    var tint: Color = Theme.amberDeep
    var action: () -> Void

    var body: some View {
        Button(action: { withAnimation(Metric.spring) { action() } }) {
            HStack(spacing: 6) {
                if let symbol = symbol { Image(systemName: symbol).font(.system(size: 12, weight: .bold)) }
                Text(text).font(.roost(14, .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundColor(selected ? .white : Theme.textSecondary)
            .background(
                Capsule().fill(selected ? tint.asGradient : Theme.card.asGradient)
            )
            .overlay(Capsule().stroke(selected ? Color.clear : Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var value: String
    var label: String
    var symbol: String
    var tint: Color = Theme.amberDeep

    var body: some View {
        RoostCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                IconBadge(symbol: symbol, tint: tint, size: 38)
                Text(value).font(.roost(24, .bold)).foregroundColor(Theme.textPrimary)
                Text(label).font(.roostCaption).foregroundColor(Theme.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double          // 0...1
    var size: CGFloat = 70
    var lineWidth: CGFloat = 9
    var tint: Color = Theme.amber

    var body: some View {
        ZStack {
            Circle().stroke(Theme.stroke, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Metric.softSpring, value: progress)
            Text("\(Int(progress * 100))%")
                .font(.roost(size * 0.24, .bold))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Empty state

struct EmptyState: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundColor(Theme.amber.opacity(0.7))
            Text(title).font(.roost(18, .semibold)).foregroundColor(Theme.textPrimary)
            Text(message).font(.roostCaption).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 20)
    }
}

// MARK: - Toast (save confirmations)

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var symbol: String = "checkmark.circle.fill"
}

struct ToastView: View {
    let toast: Toast
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol).foregroundColor(.white)
            Text(toast.message).font(.roost(15, .semibold)).foregroundColor(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Capsule().fill(Theme.wood))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.bottom, 8)
    }
}

extension View {
    /// Overlays a transient toast that auto-dismisses.
    func toast(_ toast: Binding<Toast?>) -> some View {
        ZStack {
            self
            VStack {
                Spacer()
                if let value = toast.wrappedValue {
                    ToastView(toast: value)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation(Metric.spring) { toast.wrappedValue = nil }
                            }
                        }
                }
            }
            .padding(.bottom, 90)
            .animation(Metric.spring, value: toast.wrappedValue)
        }
    }
}

// MARK: - Screen scaffold

/// Shared screen container: barn-wood background, large title, optional trailing
/// action button, and a scrolling content area. Keeps every screen consistent.
struct ScreenScaffold<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil
    var scrolls: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            BarnBackground()
            VStack(spacing: 0) {
                header
                if scrolls {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) { content() }
                            .padding(.horizontal, Metric.pad)
                            .padding(.top, 6)
                            .padding(.bottom, 120)
                    }
                } else {
                    VStack(spacing: 16) { content() }
                        .padding(.horizontal, Metric.pad)
                        .padding(.top, 6)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.roost(26, .bold)).foregroundColor(Theme.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle).font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            if let icon = trailingIcon, let action = trailingAction {
                Button(action: action) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.amberGradient))
                        .shadow(color: Theme.amberDeep.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, Metric.pad)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// A sheet container with a close (✕), centered title, optional Save button and
/// scrolling content. Used by every add/edit editor in the app.
struct SheetScaffold<Content: View>: View {
    var title: String
    var saveTitle: String = "Save"
    var saveEnabled: Bool = true
    var onSave: (() -> Void)? = nil
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            BarnBackground()
            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Theme.card))
                            .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                    }
                    Spacer()
                    Text(title).font(.roost(17, .bold)).foregroundColor(Theme.textPrimary)
                    Spacer()
                    if let onSave = onSave {
                        Button(action: onSave) {
                            Text(saveTitle).font(.roost(15, .bold))
                                .foregroundColor(saveEnabled ? Theme.amberDeep : Theme.textFaint)
                        }
                        .disabled(!saveEnabled)
                        .frame(minWidth: 38, alignment: .trailing)
                    } else {
                        Color.clear.frame(width: 38, height: 38)
                    }
                }
                .padding(.horizontal, Metric.pad)
                .padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) { content() }
                        .padding(.horizontal, Metric.pad)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

/// A back-button header for pushed detail screens.
struct DetailScaffold<Content: View>: View {
    var title: String
    @Environment(\.presentationMode) private var presentationMode
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            BarnBackground()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.card))
                            .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    Spacer()
                    Text(title).font(.roost(18, .bold)).foregroundColor(Theme.textPrimary)
                    Spacer()
                    if let icon = trailingIcon, let action = trailingAction {
                        Button(action: action) {
                            Image(systemName: icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Theme.amberGradient))
                        }
                        .buttonStyle(PressableStyle())
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, Metric.pad)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) { content() }
                        .padding(.horizontal, Metric.pad)
                        .padding(.top, 10)
                        .padding(.bottom, 60)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
