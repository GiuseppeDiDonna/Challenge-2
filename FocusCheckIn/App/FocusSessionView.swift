import SwiftUI
import UserNotifications

/// The session in full screen, as in Sketch Page 1: "Home – Focused" (orange, countdown, X to end early)
/// and the two end screens, "Session End – Completed" and "Session End – Stopped early", with their feedback.
struct FocusSessionView: View {
    let session: FocusSession
    let history: FocusHistory

    var body: some View {
        if session.actualMinutes == nil {
            if session.pausedAt != nil, let item = history.openBreak {
                RestScreen(item: item, history: history) { history.resume(session) }
            } else {
                FocusingScreen(session: session, history: history)
            }
        } else {
            SessionEndScreen(session: session, history: history)
        }
    }
}

// MARK: Focusing

private struct FocusingScreen: View {
    let session: FocusSession
    let history: FocusHistory
    @State private var confirmingEnd = false

    var body: some View {
        ZStack {
            // Sketch "Home – Focused": orange at the edges, white behind the ring.
            LinearGradient(stops: [
                .init(color: .focus.opacity(0.85), location: 0),
                .init(color: Color.canvas, location: 0.45),
                .init(color: Color.canvas, location: 0.55),
                .init(color: .focus.opacity(0.85), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            StateRing(tint: .focus, side: 260) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let remaining = Int(max(0, session.deadline.timeIntervalSince(timeline.date)).rounded(.up))
                    VStack(spacing: 2) {
                        Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                            .font(.system(size: 28, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.focusText)
                            .accessibilityLabel("Time remaining")
                            .accessibilityValue(Duration.seconds(remaining).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                        Text("left of \(session.plannedMinutes) min")
                            .font(.caption)
                            .foregroundStyle(Color.ink.opacity(0.6))
                    }
                    .onChange(of: remaining, initial: true) {
                        if remaining == 0 && !history.failed { history.finish(session) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            Button { confirmingEnd = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.35), in: .circle)
            }
            .accessibilityLabel("End early")
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            Button { history.pause(session) } label: {
                Label("Pause", systemImage: "pause.fill")
                    .font(.headline)
                    .foregroundStyle(Color.focusText)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 50)
                    .background(Color.canvas.opacity(0.75), in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .confirmationDialog("End this session early?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) { history.finish(session) }
        } message: {
            Text("You’ll tell us why on the next screen.")
        }
    }
}

// MARK: Session end

private struct SessionEndScreen: View {
    let session: FocusSession
    let history: FocusHistory
    @State private var keepGoing: KeepGoingAnswer?
    @State private var length: SessionFeedback?
    @State private var breakAnswer: BreakAnswer?
    @State private var reason: SessionFeedback?

    private var stoppedEarly: Bool { session.feedbackChoices == SessionFeedback.stoppedEarly }
    private var focused: String {
        Duration.seconds((session.actualMinutes ?? 0) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        VStack(spacing: 0) {
            ringHeader
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Large text: the panel scrolls instead of being cut.
            ViewThatFits(in: .vertical) {
                panel
                ScrollView { panel }
            }
            .background(Color.card, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
            .ignoresSafeArea(edges: .bottom)
            // The panel takes the height it needs; the ring gets what is left.
            .layoutPriority(1)
        }
        .background(Color.surface.ignoresSafeArea())
    }

    private var ringHeader: some View {
        let left = max(0, Double(session.plannedMinutes) - (session.actualMinutes ?? 0)) * 60
        return StateRing(scale: stoppedEarly ? 0.95 : 0.82) {
            VStack(spacing: 2) {
                Text("END").font(.caption.weight(.semibold)).foregroundStyle(Color.brand)
                Text(Duration.seconds(left.rounded()), format: .time(pattern: .minuteSecond))
                    .font(.system(size: 26, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.ink)
                Text(stoppedEarly ? "left of \(session.plannedMinutes) min" : "Session done")
                    .font(.caption2)
                    .foregroundStyle(Color.ink.opacity(0.6))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stoppedEarly ? "You stopped early" : "Session complete")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(stoppedEarly ? "That’s okay. Tell us why, so we can plan better."
                                  : "\(focused) of focus, nice work. Three quick taps:")
                    .font(.footnote)
                    .foregroundStyle(Color.ink.opacity(0.6))
            }
            if stoppedEarly {
                question("What made you stop?")
                grid(SessionFeedback.stoppedEarly, selected: $reason, title: \.title, image: \.systemImage)
            } else {
                question("Could you keep going?")
                grid(KeepGoingAnswer.allCases, selected: $keepGoing, title: \.title, image: \.systemImage)
                question("Was the session the right length?")
                grid(SessionFeedback.atDeadline, selected: $length, title: \.title, image: \.systemImage)
                question("Did you need a break along the way?")
                grid(BreakAnswer.allCases, selected: $breakAnswer, title: \.title, image: \.systemImage)
            }
            let ready = (stoppedEarly ? reason : length) != nil
            Button(action: done) {
                // Disabled stays readable: brand text on a pale fill, not faded white on blue.
                Text(ready ? "Done" : (stoppedEarly ? "Choose a reason" : "Answer the length question"))
                    .font(.headline)
                    .foregroundStyle(ready ? Color.canvas : Color.brand)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(ready ? Color.brand : Color.brand.opacity(0.12), in: .capsule)
                    .contentTransition(.opacity)
                    .animation(.snappy, value: ready)
            }
            .buttonStyle(.plain)
            .disabled(!ready)
            .padding(.top, 4)
            Button("Skip") {
                history.record(.skipped, for: session)
                history.startBreak(after: session)
            }
                .font(.subheadline.weight(.medium))
                .tint(.brand)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func question(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func grid<Item: Identifiable & Hashable>(_ items: [Item], selected: Binding<Item?>,
                                                     title: KeyPath<Item, LocalizedStringResource>,
                                                     image: KeyPath<Item, String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(items) { item in
                let isOn = selected.wrappedValue == item
                Button { selected.wrappedValue = item } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item[keyPath: image]).font(.body)
                        Text(item[keyPath: title]).font(.caption.weight(.medium)).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(isOn ? Color.white : Color.ink.opacity(0.8))
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(isOn ? Color.brand : Color.surface, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func done() {
        if stoppedEarly {
            guard let reason else { return }
            history.record(reason, for: session)
        } else {
            guard let length else { return }
            session.keepGoingCode = keepGoing?.rawValue
            session.breakCode = breakAnswer?.rawValue
            history.record(length, for: session)
        }
        history.startBreak(after: session)
    }
}

// MARK: Break

/// "Home – Focused Copy 2" in Sketch: light blue, "break left". During a session (Pause) or after it.
/// The suggested length is a quarter of the focus (`FocusBreak.suggestedMinutes`); turning the ring changes it.
struct RestScreen: View {
    let item: FocusBreak
    let history: FocusHistory
    /// During a session: back to focus. Nil after a session: the break ends at Home.
    var resume: (() -> Void)?

    private static let ringSide: CGFloat = 260
    private static let minutesPerTurn = 12.0
    @State private var minutes: Int
    @State private var rawMinutes: Double
    @State private var lastAngle: Double?
    @State private var over = false

    init(item: FocusBreak, history: FocusHistory, resume: (() -> Void)? = nil) {
        self.item = item
        self.history = history
        self.resume = resume
        // Set before the first frame: with 0 the countdown would read the break as already over.
        _minutes = State(initialValue: item.plannedMinutes)
        _rawMinutes = State(initialValue: Double(item.plannedMinutes))
    }

    private var ends: Date { item.startedAt.addingTimeInterval(Double(minutes) * 60) }

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: .rest.opacity(0.9), location: 0),
                .init(color: Color.canvas, location: 0.45),
                .init(color: Color.canvas, location: 0.55),
                .init(color: .rest.opacity(0.9), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                ring
                VStack(spacing: 4) {
                    Text(over ? "Ready to focus again?" : "Suggested \(item.suggestedMinutes) min · after \(Int(item.focusSinceLastBreak.rounded())) min of focus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    if !over {
                        Text("Turn the ring to change it")
                            .font(.footnote)
                            .foregroundStyle(Color.ink.opacity(0.6))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                Spacer()
                Button(action: finish) {
                    Text(over ? (resume == nil ? "Done" : "Resume focus") : (resume == nil ? "Skip break" : "Resume now"))
                        .font(.headline)
                        .foregroundStyle(over ? Color.canvas : Color.restText)
                        .padding(.horizontal, 28)
                        .frame(minHeight: 50)
                        .background(over ? Color.restText : Color.canvas.opacity(0.75), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
        }
        .onAppear { BreakReminder.schedule(at: ends) }
        .sensoryFeedback(.success, trigger: over) { _, next in next }
        .sensoryFeedback(.selection, trigger: minutes)
    }

    private var ring: some View {
        StateRing(tint: .rest) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let left = Int(max(0, ends.timeIntervalSince(timeline.date)).rounded(.up))
                VStack(spacing: 2) {
                    Text(Duration.seconds(left), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 28, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.restText)
                    Text("break left").font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                }
                .onChange(of: left, initial: true) { if left == 0 { over = true } }
            }
        }
        .frame(width: Self.ringSide, height: Self.ringSide)
        .contentShape(Circle())
        .gesture(turn, including: over ? .none : .all)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("breakRing")
        .accessibilityLabel("Break length")
        .accessibilityValue("\(minutes) minutes")
        .accessibilityAdjustableAction { direction in
            guard !over else { return }
            setMinutes(Double(minutes + (direction == .increment ? 1 : -1)))
            commit()
        }
    }

    private var turn: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = Self.ringSide / 2
                guard hypot(value.location.x - center, value.location.y - center) > Self.ringSide * 0.16 else {
                    lastAngle = nil
                    return
                }
                let next = atan2(value.location.y - center, value.location.x - center)
                if let previous = lastAngle {
                    setMinutes(rawMinutes + atan2(sin(next - previous), cos(next - previous)) / (2 * .pi) * Self.minutesPerTurn)
                }
                lastAngle = next
            }
            .onEnded { _ in
                lastAngle = nil
                commit()
            }
    }

    private func setMinutes(_ proposed: Double) {
        rawMinutes = min(30, max(1, proposed))
        minutes = Int(rawMinutes.rounded())
    }

    private func commit() {
        history.setLength(minutes, of: item)
        BreakReminder.schedule(at: ends)
    }

    private func finish() {
        BreakReminder.cancel()
        if let resume { resume() } else { history.endBreak(item) }
    }
}

/// A local notification at the end of a break, for when the app is not on screen.
/// Permission is asked the first time a break starts, when its purpose is clear.
enum BreakReminder {
    private static let identifier = "breakEnd"

    static func schedule(at date: Date) {
        #if DEBUG
        // UI tests: no permission alert in the way.
        if UserDefaults.standard.string(forKey: "focusTestHistory") != nil { return }
        #endif
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "Break’s over"
            content.body = "Ready to focus again?"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
