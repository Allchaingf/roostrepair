//
//  OnboardingView.swift
//  RoostRepair
//
//  Four onboarding screens, each with a unique illustrated scene and a distinct
//  interactive gesture:
//    1. Farm Style    — tap the coop to burst feathers + pick a board mode
//    2. Bird Groups   — drag an egg into the nest + create the first group
//    3. Care Priorities — scroll-driven reveal of priority cards
//    4. Ready         — long-press "hold to open" ring
//  Completion is stored in AppSettings.hasCompletedOnboarding (@AppStorage backed).
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: FarmStore

    @State private var page = 0

    // Screen 1
    @State private var selectedMode: FarmViewMode = .coopMap
    // Screen 2
    @State private var groupName = ""
    @State private var groupType: BirdType = .chicken
    @State private var groupCount = 6
    @State private var groupAdded = false
    // Screen 3
    @State private var selectedPriorities: Set<CarePriority> = [.health, .feed]

    var body: some View {
        ZStack {
            BarnBackground()
            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    FarmStylePage(selectedMode: $selectedMode).tag(0)
                    BirdGroupsPage(name: $groupName, type: $groupType,
                                   count: $groupCount, added: $groupAdded).tag(1)
                    CarePrioritiesPage(selected: $selectedPriorities).tag(2)
                    ReadyPage(mode: selectedMode, priorities: selectedPriorities,
                              hasGroup: !groupName.trimmingCharacters(in: .whitespaces).isEmpty,
                              onOpen: finish).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(Metric.spring, value: page)

                controls
            }
        }
    }

    // MARK: Top bar (page dots + skip)
    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i == page ? Theme.amber : Theme.stroke)
                        .frame(width: i == page ? 22 : 8, height: 8)
                        .animation(Metric.spring, value: page)
                }
            }
            Spacer()
            Button("Skip") { finish() }
                .font(.roost(15, .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: Bottom controls
    private var controls: some View {
        VStack(spacing: 12) {
            if page < 3 {
                PrimaryButton(title: ctaTitle, icon: ctaIcon) { advance() }
                    .padding(.horizontal, 22)
            }
            if page > 0 {
                Button("Back") { withAnimation(Metric.spring) { page -= 1 } }
                    .font(.roost(14, .semibold))
                    .foregroundColor(Theme.textFaint)
            }
        }
        .padding(.bottom, 26)
    }

    private var ctaTitle: String {
        switch page {
        case 0: return "Next"
        case 1: return groupName.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip Group" : "Add Group"
        case 2: return "Set Priorities"
        default: return "Open Dashboard"
        }
    }
    private var ctaIcon: String {
        switch page {
        case 1: return "plus.circle.fill"
        case 2: return "checkmark.circle.fill"
        default: return "arrow.right"
        }
    }

    private func advance() {
        if page == 1 { addGroupIfNeeded() }
        if page == 2 { settings.priorities = selectedPriorities }
        withAnimation(Metric.spring) { page += 1 }
    }

    private func addGroupIfNeeded() {
        let trimmed = groupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !groupAdded else { return }
        let g = BirdGroup(name: trimmed, type: groupType, count: groupCount,
                          colorHex: [0xE8A33D, 0xCE7C24, 0x4E8FA8, 0xA8392E].randomElement()!)
        store.addGroup(g)
        groupAdded = true
    }

    private func finish() {
        settings.viewMode = selectedMode
        settings.priorities = selectedPriorities.isEmpty ? [.health, .feed] : selectedPriorities
        addGroupIfNeeded()
        // Seed sample data on first run so the board isn't empty.
        store.seedSampleDataIfNeeded()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            settings.hasCompletedOnboarding = true
        }
    }
}

// MARK: - Page 1: Farm Style (tap-to-burst)

private struct FarmStylePage: View {
    @Binding var selectedMode: FarmViewMode
    @State private var particles: [BurstParticle] = []
    @State private var pop = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Text("Make every check visible")
                    .font(.roost(30, .bold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("Tap the coop, then choose how your board should look.")
                    .font(.roostBody).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                // Tap-to-burst coop scene.
                ZStack {
                    Circle().fill(Theme.amberSoft).frame(width: 170, height: 170)
                    ForEach(particles) { p in
                        Image(systemName: "leaf.fill")
                            .foregroundColor(Theme.amber)
                            .font(.system(size: 16))
                            .offset(x: p.dx, y: p.dy)
                            .opacity(p.opacity)
                    }
                    Image(systemName: "house.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(Theme.wood)
                        .scaleEffect(pop ? 1.15 : 1)
                }
                .frame(height: 190)
                .onTapGesture { burst() }

                VStack(spacing: 12) {
                    ForEach(FarmViewMode.allCases) { mode in
                        modeCard(mode)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }

    private func modeCard(_ mode: FarmViewMode) -> some View {
        Button(action: { withAnimation(Metric.spring) { selectedMode = mode } }) {
            HStack(spacing: 14) {
                IconBadge(symbol: mode.symbol,
                          tint: selectedMode == mode ? Theme.amberDeep : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title).font(.roost(17, .semibold)).foregroundColor(Theme.textPrimary)
                    Text(mode.subtitle).font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedMode == mode ? Theme.amber : Theme.stroke)
                    .font(.system(size: 22))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Metric.radius)
                .stroke(selectedMode == mode ? Theme.amber : Theme.stroke, lineWidth: selectedMode == mode ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func burst() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring()) { pop = false }
        }
        particles = (0..<10).map { i in
            BurstParticle(id: UUID(), angle: Double(i) / 10 * 2 * .pi)
        }
        for i in particles.indices {
            let angle = particles[i].angle
            withAnimation(.easeOut(duration: 0.7)) {
                particles[i].dx = CGFloat(cos(angle)) * 90
                particles[i].dy = CGFloat(sin(angle)) * 90
                particles[i].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { particles = [] }
    }
}

private struct BurstParticle: Identifiable {
    let id: UUID
    let angle: Double
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var opacity: Double = 1
}

// MARK: - Page 2: Bird Groups (drag the egg into the nest)

private struct BirdGroupsPage: View {
    @Binding var name: String
    @Binding var type: BirdType
    @Binding var count: Int
    @Binding var added: Bool

    @State private var eggOffset: CGSize = .zero
    @State private var docked = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Create your first group")
                    .font(.roost(30, .bold)).foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Drag the egg into the nest, then name your flock.")
                    .font(.roostBody).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                // Drag scene
                ZStack {
                    // Nest target
                    VStack(spacing: 4) {
                        Image(systemName: docked ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.system(size: 30))
                            .foregroundColor(docked ? Theme.ok : Theme.stroke)
                        Image(systemName: "tray.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.wood)
                    }
                    .offset(x: 90, y: 6)

                    // Draggable egg
                    Image(systemName: "oval.fill")
                        .font(.system(size: 42))
                        .foregroundColor(docked ? Theme.amberDeep : Theme.amber)
                        .offset(x: -80 + eggOffset.width, y: eggOffset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { v in eggOffset = v.translation }
                                .onEnded { v in
                                    // Dropped near the nest?
                                    if v.translation.width > 120 {
                                        withAnimation(Metric.spring) { docked = true; eggOffset = CGSize(width: 170, height: 6) }
                                    } else {
                                        withAnimation(Metric.spring) { eggOffset = .zero }
                                    }
                                }
                        )
                }
                .frame(height: 120)

                RoostCard {
                    VStack(spacing: 14) {
                        RoostField(title: "Group name", placeholder: "e.g. Brown Layers", text: $name, icon: "tag.fill")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BIRD TYPE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(BirdType.allCases) { t in
                                        SelectChip(text: t.title, symbol: t.symbol, selected: type == t) { type = t }
                                    }
                                }
                            }
                        }
                        RoostStepper(title: "Approx. count", value: $count, range: 1...2000)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Page 3: Care Priorities (scroll-driven reveal)

private struct CarePrioritiesPage: View {
    @Binding var selected: Set<CarePriority>

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("What matters today?")
                    .font(.roost(30, .bold)).foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Pick the priorities that should rise to the top of your board. Scroll to explore.")
                    .font(.roostBody).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                ForEach(CarePriority.allCases) { p in
                    GeometryReader { geo in
                        let midY = geo.frame(in: .global).midY
                        // Scroll-driven: cards scale/opacity based on vertical position.
                        let screenH = UIScreen.main.bounds.height
                        let distance = abs(midY - screenH * 0.5)
                        let scale = max(0.9, 1.05 - distance / 1400)
                        priorityCard(p)
                            .scaleEffect(scale)
                            .opacity(Double(max(0.55, 1.1 - distance / 700)))
                    }
                    .frame(height: 92)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }

    private func priorityCard(_ p: CarePriority) -> some View {
        let isOn = selected.contains(p)
        return Button(action: {
            withAnimation(Metric.spring) {
                if isOn { selected.remove(p) } else { selected.insert(p) }
            }
        }) {
            HStack(spacing: 14) {
                IconBadge(symbol: p.symbol, tint: p.tint, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.title).font(.roost(18, .semibold)).foregroundColor(Theme.textPrimary)
                    Text("Bubble up \(p.title.lowercased()) cards")
                        .font(.roostCaption).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isOn ? p.tint : Theme.stroke)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Metric.radius)
                .stroke(isOn ? p.tint : Theme.stroke, lineWidth: isOn ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Page 4: Ready (long-press to open)

private struct ReadyPage: View {
    var mode: FarmViewMode
    var priorities: Set<CarePriority>
    var hasGroup: Bool
    var onOpen: () -> Void

    @State private var holdProgress: Double = 0
    @State private var holding = false
    @State private var timer: Timer?

    private var firstSections: [(String, String)] {
        var out: [(String, String)] = [("square.grid.2x2.fill", "Dashboard board (\(mode.title))")]
        if hasGroup { out.append(("oval.fill", "Your first bird group")) }
        if priorities.contains(.health) { out.append(("heart.text.square.fill", "Health observations")) }
        if priorities.contains(.feed) { out.append(("bag.fill", "Feed planner & water log")) }
        if priorities.contains(.cleaning) { out.append(("sparkles", "Cleaning schedule")) }
        if priorities.contains(.transport) { out.append(("car.fill", "Routes & transport prep")) }
        out.append(("shippingbox.fill", "Inventory & sample records"))
        return out
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Your farm board is ready")
                    .font(.roost(30, .bold)).foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("These sections will be filled in first:")
                    .font(.roostBody).foregroundColor(Theme.textSecondary)

                RoostCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(firstSections.enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 12) {
                                IconBadge(symbol: item.0, tint: Theme.amberDeep, size: 34)
                                Text(item.1).font(.roostBody).foregroundColor(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "checkmark").foregroundColor(Theme.ok).font(.system(size: 13, weight: .bold))
                            }
                        }
                    }
                }

                // Long-press "hold to open" ring (unique gesture).
                ZStack {
                    Circle().stroke(Theme.stroke, lineWidth: 10).frame(width: 130, height: 130)
                    Circle().trim(from: 0, to: holdProgress)
                        .stroke(Theme.amber, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 130, height: 130)
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 30)).foregroundColor(Theme.amberDeep)
                        Text(holding ? "Keep holding" : "Hold to open").font(.roost(12, .bold)).foregroundColor(Theme.textSecondary)
                    }
                }
                .scaleEffect(holding ? 1.05 : 1)
                .animation(Metric.spring, value: holding)
                .onLongPressGesture(minimumDuration: 0.7, maximumDistance: 40,
                                    pressing: { isPressing in
                                        holding = isPressing
                                        isPressing ? startHold() : cancelHold()
                                    }, perform: {})

                Text("…or just tap below")
                    .font(.roostCaption).foregroundColor(Theme.textFaint)
                Button(action: complete) {
                    Text("Open Dashboard").font(.roost(15, .semibold)).foregroundColor(Theme.amberDeep)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .onDisappear { timer?.invalidate() }
    }

    private func startHold() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
            holdProgress += 0.02 / 0.7
            if holdProgress >= 1 { t.invalidate(); complete() }
        }
    }
    private func cancelHold() {
        timer?.invalidate()
        if holdProgress < 1 { withAnimation(Metric.spring) { holdProgress = 0 } }
    }
    private func complete() {
        timer?.invalidate()
        onOpen()
    }
}
