//
//  LaunchView.swift
//  RoostRepair
//
//  Thematic splash: a barn-wood gradient that shifts, drifting feathers + a
//  pulsing amber roost ring (midground), and a spring-in coop/wrench logo with
//  the app name (foreground). Driven by a single coordinator timer; every loop
//  is stopped on disappear so nothing animates into the main app.
//

import SwiftUI

struct LaunchView: View {
    var onFinish: () -> Void

    // Phase flags
    @State private var isVisible = true
    @State private var bgIn = false
    @State private var gradientShift = false
    @State private var feathersDrift = false
    @State private var ringPulse = false
    @State private var logoIn = false
    @State private var titleIn = false
    @State private var exiting = false

    @State private var elapsed: Double = 0
    @State private var timer: Timer?

    // Pre-baked feather descriptors (stable across redraws).
    private let feathers: [Feather] = (0..<14).map { i in
        Feather(
            x: CGFloat.random(in: 0.05...0.95),
            startY: CGFloat.random(in: 0.6...1.1),
            size: CGFloat.random(in: 14...30),
            delay: Double(i) * 0.12,
            drift: CGFloat.random(in: -40...40),
            rotation: Double.random(in: -40...40)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1 — shifting barn-wood gradient.
                Theme.splashGradient(gradientShift ? 1 : 0)
                    .ignoresSafeArea()
                    .opacity(bgIn ? 1 : 0)

                // Layer 2 — drifting feathers (midground loop).
                ForEach(feathers) { feather in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: feather.size, weight: .regular))
                        .foregroundColor(Theme.amber.opacity(0.45))
                        .rotationEffect(.degrees(feather.rotation + (feathersDrift ? 18 : -18)))
                        .position(
                            x: geo.size.width * feather.x + (feathersDrift ? feather.drift : -feather.drift),
                            y: geo.size.height * (feathersDrift ? feather.startY - 0.7 : feather.startY)
                        )
                        .opacity(feathersDrift ? 0.0 : 0.7)
                        .animation(
                            Animation.easeInOut(duration: 3.2)
                                .repeatForever(autoreverses: false)
                                .delay(feather.delay),
                            value: feathersDrift
                        )
                }

                // Layer 2b — pulsing roost ring behind the logo.
                Circle()
                    .stroke(Theme.amber.opacity(0.5), lineWidth: 3)
                    .frame(width: 190, height: 190)
                    .scaleEffect(ringPulse ? 1.18 : 0.8)
                    .opacity(ringPulse ? 0.0 : 0.6)
                    .animation(Animation.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: ringPulse)

                // Layer 3 — logo + title (foreground spring entrance).
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: 0xFFFBF2), Color(hex: 0xF6DEB0)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 132, height: 132)
                            .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
                        // Coop + wrench mark.
                        ZStack {
                            Image(systemName: "house.fill")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(Theme.wood)
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Theme.rust)
                                .offset(x: 1, y: 14)
                        }
                    }
                    .scaleEffect(logoIn ? (exiting ? 1.6 : 1) : 0.4)
                    .opacity(logoIn ? (exiting ? 0 : 1) : 0)

                    VStack(spacing: 4) {
                        Text("Roost Repair")
                            .font(.roost(34, .bold))
                            .foregroundColor(.white)
                        Text("Keep every coop in good repair")
                            .font(.roost(14, .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .opacity(titleIn ? (exiting ? 0 : 1) : 0)
                    .offset(y: titleIn ? 0 : 16)
                }
                .scaleEffect(exiting ? 1.15 : 1)
            }
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    // MARK: - Coordinator timer

    private func start() {
        isVisible = true
        // Kick off infinite loops.
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { gradientShift = true }
        feathersDrift = true
        ringPulse = true

        // Phase 1 — background builds in.
        withAnimation(.easeOut(duration: 0.6)) { bgIn = true }

        // Single coordinator timer drives the staged sequence.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            guard isVisible else { t.invalidate(); return }
            elapsed += 0.1

            if elapsed >= 1.4 && !logoIn {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { logoIn = true }
            }
            if elapsed >= 1.7 && !titleIn {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { titleIn = true }
            }
            if elapsed >= 2.4 && !exiting {
                withAnimation(.easeIn(duration: 0.45)) { exiting = true }
            }
            if elapsed >= 2.9 {
                t.invalidate()
                onFinish()
            }
        }
    }

    private func stop() {
        // Stop every loop cleanly so nothing leaks into the main app.
        isVisible = false
        timer?.invalidate()
        timer = nil
        gradientShift = false
        feathersDrift = false
        ringPulse = false
    }
}

private struct Feather: Identifiable {
    let id = UUID()
    let x: CGFloat
    let startY: CGFloat
    let size: CGFloat
    let delay: Double
    let drift: CGFloat
    let rotation: Double
}
