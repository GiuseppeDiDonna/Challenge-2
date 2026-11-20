import SwiftUI

/// The Home (Sketch Page 6, "E - Energia" and "M3 - giri da 60 min"): the logo is the only control.
/// One long press (`holdToArm` seconds) charges the rings and opens the choice, which stays open when the finger lifts.
/// A knob on an arc above the logo picks the energy (Low · Steady · Charged); release to set it. The arc then opens
/// into a full dial, one turn = 60 minutes: turn to set the time and release to start, with no second long press.
struct HomeScreen: View {
    static let minutesRange = 15...180
    static let minutesInterval = 15
    static let holdToArm = 1.0
    private static let ringSide: CGFloat = 250
    /// The touch area and the dial around the logo.
    private static let dialSide: CGFloat = 360
    private static let trackRadius: CGFloat = 162
    /// One full turn of the dial (Sketch M3).
    private static let minutesPerTurn = 60.0
    /// The energy knob travels ±60° from the top; levels change at ±30°.
    private static let energySpan = Double.pi / 3

    let greeting: String
    @Binding var energy: FocusEnergy?
    @Binding var minutes: Int
    let starting: Bool
    /// Pushed by the top-right button, with the standard Back button (HIG: secondary destination).
    let insights: InsightsView
    let start: () -> Void

    @ScaledMetric(relativeTo: .body) private var scale = 1.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var scenePhase
    @State private var holdTask: Task<Void, Never>?
    @State private var touching = false
    /// The choice is open: it stays open when the finger lifts, until a release commits it.
    @State private var armed = false
    /// The current touch is the long press that opened the choice: lifting it without turning keeps the choice open.
    @State private var armingTouch = false
    @State private var turnedThisTouch = false
    @State private var level: FocusEnergy?
    @State private var turn = 0.0
    @State private var lastAngle: Double?
    @State private var rawMinutes = 45.0
    /// 0...1 while the long press charges the rings.
    @State private var charge = 0.0

    /// Energy is set: the dial now sets the time.
    private var settingTime: Bool { energy != nil }

    private var hint: String {
        if starting { return "Starting your session…" }
        if armed && touching { return settingTime ? "Turn to set the time · Release to start" : "Turn to choose · Release to set" }
        // After the energy the choice stays open: the time needs no second long press.
        if armed { return settingTime ? "Touch and turn to set the time" : "Touch and turn to choose" }
        if touching { return "Keep holding…" }
        if settingTime { return "Hold the rings to set your time" }
        return "Hold the rings to check in"
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            if dynamicTypeSize.isAccessibilitySize {
                // Too much text for the artboard layout: the same parts, in a column that scrolls.
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        dial
                        hintText.multilineTextAlignment(.center).padding(.horizontal, 28)
                        controls
                    }
                }
            } else {
                ZStack {
                    ZStack {
                        dial
                        hintText.offset(y: 226)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    header.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    controls.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .onDisappear { cancelTouch() }
        .onChange(of: scenePhase) { if scenePhase != .active { cancelTouch() } }
        .sensoryFeedback(.impact(weight: .medium), trigger: armed) { _, next in next }
        .sensoryFeedback(.selection, trigger: level) { _, next in next != nil }
        .sensoryFeedback(.selection, trigger: minutes)
    }

    // MARK: Dial

    private var dial: some View {
        ZStack {
            // A soft halo of the phase colour that grows with the charge.
            Circle()
                .fill(RadialGradient(colors: [Color.brand.opacity(0.10 + 0.14 * charge), .clear],
                                     center: .center, startRadius: 30, endRadius: Self.dialSide / 2))
            if armed {
                track
                if settingTime { lapProgress }
                marks
                knob
            }
            // While the dial is open the logo steps back a little, leaving room for the marks.
            StateRing(scale: armed ? 0.88 : 1, charge: charge, side: Self.ringSide) { centerLabel }
                .scaleEffect(!armed && touching ? 0.95 : 1)
                .animation(reduced ? nil : .spring(duration: 0.4, bounce: 0.35), value: touching)
        }
        .frame(width: Self.dialSide, height: Self.dialSide)
        .animation(reduced ? nil : .spring(duration: 0.55, bounce: 0.25), value: armed)
        .animation(reduced ? nil : .spring(duration: 0.6, bounce: 0.2), value: settingTime)
        .contentShape(Circle())
        .gesture(touch, including: starting ? .none : .all)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("ringButton")
        .accessibilityLabel(settingTime ? "Focus duration" : "Energy")
        .accessibilityValue(settingTime ? "\(minutes) minutes" : hint)
        .accessibilityActions {
            if !settingTime {
                ForEach(FocusEnergy.allCases) { value in
                    Button(value.title) { energy = value }
                }
            } else {
                Button("Start focus") { if !starting { start() } }
            }
        }
        .accessibilityAdjustableAction { direction in
            guard settingTime, !starting else { return }
            switch direction {
            case .increment: setMinutes(Double(minutes + Self.minutesInterval))
            case .decrement: setMinutes(Double(minutes - Self.minutesInterval))
            @unknown default: break
            }
        }
    }

    /// The energy arc (a third of the circle, centred on the top) opens into the full time dial.
    private var track: some View {
        Circle()
            .trim(from: 0, to: settingTime ? 1 : 1.0 / 3)
            .stroke(Color.brand.opacity(settingTime ? 0.14 : 0.2), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .frame(width: Self.trackRadius * 2, height: Self.trackRadius * 2)
            .rotationEffect(.degrees(settingTime ? -90 : -150))
            .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    /// Finished laps as a full ring, the current lap as an arc from the top.
    private var lapProgress: some View {
        ZStack {
            if completedLaps > 0 {
                Circle()
                    .stroke(Color.brand.opacity(0.25 + 0.2 * Double(completedLaps)), lineWidth: 12)
            }
            Circle()
                .trim(from: 0, to: lapFraction)
                .stroke(Color.brand, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: Self.trackRadius * 2, height: Self.trackRadius * 2)
        .transition(.opacity)
    }

    private var knob: some View {
        let angle = knobAngle
        return Circle()
            .fill(Color.brand)
            .overlay(Circle().stroke(Color.canvas, lineWidth: 4))
            .frame(width: 28, height: 28)
            .shadow(color: Color.brand.opacity(0.35), radius: 8, y: 3)
            .scaleEffect(touching ? 1.2 : 1)
            .offset(x: Self.trackRadius * cos(angle), y: Self.trackRadius * sin(angle))
            .animation(reduced ? nil : .interactiveSpring(duration: 0.25), value: angle)
            .animation(reduced ? nil : .spring(duration: 0.3, bounce: 0.4), value: touching)
            .transition(.scale.combined(with: .opacity))
    }

    /// Minute marks sit between the logo and the track; the energy names sit under the ends of the arc.
    /// Both stay inside the dial, so nothing reaches the screen edge or the rings.
    @ViewBuilder private var marks: some View {
        if settingTime {
            ForEach([0, 15, 30, 45], id: \.self) { mark in
                let angle = -.pi / 2 + Double(mark) / 60 * 2 * .pi
                markText(Text("\(mark)"), selected: false)
                    .offset(x: 132 * cos(angle), y: 132 * sin(angle))
            }
        } else {
            ForEach([FocusEnergy.low, .high], id: \.self) { value in
                let angle = -.pi / 2 + (value == .low ? -1 : 1) * Self.energySpan
                markText(Text(value.title), selected: level == value)
                    .offset(x: Self.trackRadius * cos(angle), y: Self.trackRadius * sin(angle) + 26)
            }
        }
    }

    private func markText(_ text: Text, selected: Bool) -> some View {
        text
            .font(font(13, selected ? .bold : .semibold))
            .foregroundStyle(selected ? Color.brand : Color.ink.opacity(0.55))
            .fixedSize()
            .transition(.opacity)
    }

    @ViewBuilder private var centerLabel: some View {
        if settingTime {
            VStack(spacing: 0) {
                Text("\(minutes)")
                    .font(font(30, .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(minutes)))
                    .animation(reduced ? nil : .snappy, value: minutes)
                Text(armed ? "lap \(completedLaps + 1) of 3" : "min")
                    .font(font(11, .semibold))
                    .opacity(0.6)
            }
            .foregroundStyle(Color.brand)
            .transition(.blurReplace)
        } else if armed, let level {
            Text(level.title)
                .font(font(18, .bold))
                .foregroundStyle(Color.brand)
                .id(level)
                .transition(.blurReplace)
        }
    }

    private var hintText: some View {
        Text(hint)
            .font(font(14, .medium))
            .foregroundStyle(Color.brand.opacity(0.7))
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: hint)
    }

    // MARK: Geometry

    private var completedLaps: Int { max(0, Int((rawMinutes - 0.001) / Self.minutesPerTurn)) }

    private var lapFraction: Double {
        (rawMinutes - Double(completedLaps) * Self.minutesPerTurn) / Self.minutesPerTurn
    }

    /// Radians, 0 at 3 o'clock, clockwise (screen coordinates).
    private var knobAngle: Double {
        if settingTime { return -.pi / 2 + lapFraction * 2 * .pi }
        // While turning the knob follows the finger; at rest it sits on the chosen level.
        let offset = touching ? turn : Double((FocusEnergy.allCases.firstIndex(of: level ?? .medium) ?? 1) - 1) * Self.energySpan
        return -.pi / 2 + offset
    }

    // MARK: Controls

    /// Change the energy, or cancel the open choice.
    private var controls: some View {
        VStack(spacing: 12) {
            if settingTime, let energy, !touching {
                Button(action: changeEnergy) {
                    Text("Energy · \(Text(energy.title))")
                }
                .buttonStyle(.glass)
                .disabled(starting)
            }
            if armed, !touching {
                Button("Cancel") {
                    closeChoice()
                    energy = nil
                }
            }
        }
        .font(font(15, .medium))
        .tint(.brand)
        .padding(.bottom, 8)
        .animation(reduced ? nil : .snappy, value: armed)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(font(30, .bold))
                    .foregroundStyle(Color.brand)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(Self.dateLine)
                    .font(font(12))
                    .kerning(1)
                    .foregroundStyle(Color.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            NavigationLink {
                insights
            } label: {
                Label("Insights", systemImage: "chart.bar.xaxis")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(starting)
        }
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.top, 10)
    }

    // MARK: Gesture

    private var touch: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !starting else { return }
                if !touching { beginTouch() }
                guard armed else { return }
                let center = Self.dialSide / 2
                // Near the centre the angle jumps: turning counts only away from it.
                guard hypot(value.location.x - center, value.location.y - center) > 40 else {
                    lastAngle = nil
                    return
                }
                let next = atan2(value.location.y - center, value.location.x - center)
                if let previous = lastAngle {
                    let delta = atan2(sin(next - previous), cos(next - previous))
                    turnedThisTouch = true
                    if settingTime {
                        setMinutes(rawMinutes + delta / (2 * .pi) * Self.minutesPerTurn)
                    } else {
                        turn = min(Self.energySpan, max(-Self.energySpan, turn + delta))
                        let index = 1 + Int((turn / Self.energySpan).rounded())
                        if level != FocusEnergy.allCases[index] { level = FocusEnergy.allCases[index] }
                    }
                }
                lastAngle = next
            }
            .onEnded { _ in
                let commit = armed && (!armingTouch || turnedThisTouch)
                endTouch()
                guard commit else { return }
                if settingTime {
                    if !starting { start() }
                    closeChoice()
                } else {
                    // The choice stays open for the time.
                    energy = level
                    level = nil
                    turn = 0
                    rawMinutes = Double(minutes)
                }
            }
    }

    private func beginTouch() {
        touching = true
        turnedThisTouch = false
        lastAngle = nil
        guard !armed else {
            armingTouch = false
            return
        }
        withAnimation(reduced ? nil : .linear(duration: Self.holdToArm)) { charge = 1 }
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.holdToArm))
            guard !Task.isCancelled else { return }
            rawMinutes = Double(minutes)
            turn = 0
            armingTouch = true
            armed = true
            if !settingTime { level = .medium }
            withAnimation(reduced ? nil : .spring(duration: 0.6)) { charge = 0.35 }
        }
    }

    /// The finger lifts: a long press that is still short is dropped; an open choice stays open.
    private func endTouch() {
        holdTask?.cancel()
        holdTask = nil
        touching = false
        lastAngle = nil
        if !armed { withAnimation(reduced ? nil : .spring(duration: 0.4)) { charge = 0 } }
    }

    /// Back to the energy; the choice stays open, so no new long press.
    private func changeEnergy() {
        energy = nil
        if armed {
            level = .medium
            turn = 0
        }
    }

    private func closeChoice() {
        armed = false
        armingTouch = false
        level = nil
        turn = 0
        withAnimation(reduced ? nil : .spring(duration: 0.4)) { charge = 0 }
    }

    private func cancelTouch() {
        endTouch()
        closeChoice()
    }

    private func setMinutes(_ proposed: Double) {
        rawMinutes = min(Double(Self.minutesRange.upperBound), max(Double(Self.minutesRange.lowerBound), proposed))
        minutes = Int((rawMinutes / Double(Self.minutesInterval)).rounded()) * Self.minutesInterval
    }

    // MARK: Helpers

    /// "TUESDAY, 17 NOV", as in the design (the interface is English-only for now).
    private static var dateLine: String {
        let en = Locale(identifier: "en_GB")
        let now = Date.now
        let weekday = now.formatted(.dateTime.weekday(.wide).locale(en))
        let day = now.formatted(.dateTime.day().locale(en))
        let month = now.formatted(.dateTime.month(.abbreviated).locale(en))
        return "\(weekday), \(day) \(month)".uppercased()
    }

    private func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight, design: .rounded)
    }
}
