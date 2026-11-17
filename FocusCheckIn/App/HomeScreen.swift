import SwiftUI

/// The two Home screens of the Sketch design: "Home - main" (the ring) and "Home – after click" (energy and duration).
/// Measures are the Sketch ones on the 402×874 pt artboard (iPhone 17); fonts are Sketch's sizes, scaled with Dynamic Type.
struct HomeScreen: View {
    static let minutesRange = 15...180
    static let minutesInterval = 15

    let greeting: String
    let period: String
    @Binding var checkingIn: Bool
    @Binding var energy: FocusEnergy?
    @Binding var minutes: Int
    let canStart: Bool
    let start: () -> Void

    @ScaledMetric(relativeTo: .body) private var scale = 1.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if checkingIn {
                checkIn
            } else {
                main
            }
        }
    }

    // MARK: Home - main

    @ViewBuilder private var main: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Too much text for the artboard layout: the same parts, in a column that scrolls.
            ScrollView {
                VStack(spacing: 24) {
                    header
                    ringGroup
                    tapHint.multilineTextAlignment(.center).padding(.horizontal, 28)
                }
            }
        } else {
            ZStack {
                ZStack {
                    ringGroup
                    tapHint.offset(y: 231)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                header.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var ringGroup: some View {
        ZStack {
            Circle().stroke(Self.guide, lineWidth: 1).frame(width: 388, height: 388)
            Circle().stroke(Self.guide, lineWidth: 1).frame(width: 260, height: 260)
            Button {
                checkingIn = true
            } label: {
                StateRing()
                    .frame(width: 260, height: 260)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Check in")
            .accessibilityHint("Opens the energy check-in")
            .accessibilityIdentifier("ringButton")
        }
    }

    private var tapHint: some View {
        Text("Tap the ball to check in")
            .font(font(14, .medium))
            .foregroundStyle(Color.brand.opacity(0.6))
    }

    // MARK: Home – after click

    private var checkIn: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                StateRing(scale: 0.78).padding(.top, 17)
                VStack(alignment: .leading, spacing: 3) {
                    Text("How’s your energy today?")
                        .font(font(24, .bold))
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick the one that matches how you feel this \(period).")
                        .font(font(14))
                        .foregroundStyle(Color.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 31)
                energyCards.padding(.top, 18)
                Text("How long do you want to focus?")
                    .font(font(15, .medium))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 23)
                    .accessibilityAddTraits(.isHeader)
                durationRow.padding(.top, 10)
                Text("Changes in 15-minute steps · breaks are added for you")
                    .font(font(11))
                    .foregroundStyle(Color.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                startButton.padding(.top, 13)
            }
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.dateLine)
                .font(font(12))
                .kerning(1)
                .foregroundStyle(Color.ink.opacity(0.5))
            Text(greeting)
                .font(font(30, .bold))
                .foregroundStyle(Color.brand)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 10)
    }

    private var energyCards: some View {
        // Side by side normally; stacked when the text is too large for three columns.
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
            ForEach(FocusEnergy.allCases) { level in
                energyCard(level)
            }
        }
        .padding(.horizontal, 28)
    }

    private func energyCard(_ level: FocusEnergy) -> some View {
        let selected = energy == level
        let dot: (size: CGFloat, opacity: Double) = switch level {
        case .low: (14, 0.4)
        case .medium: (20, 0.7)
        case .high: (26, 1)
        }
        return Button {
            energy = level
        } label: {
            VStack(spacing: 0) {
                Circle()
                    .fill(selected ? Color.white : Color.brand.opacity(dot.opacity))
                    .frame(width: dot.size, height: dot.size)
                    .frame(height: 26)
                    .padding(.top, 15)
                Text(level.title)
                    .font(font(14))
                    .foregroundStyle(selected ? Color.white : Color.ink.opacity(0.7))
                    .padding(.top, 9)
                Text(level.caption)
                    .font(font(11))
                    .foregroundStyle(selected ? Color.white.opacity(0.7) : Color.ink.opacity(0.5))
                    .padding(.top, 3)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
            .background(selected ? Color.brand : Color.surface, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(level.title))
        .accessibilityHint(Text(level.caption))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var durationRow: some View {
        TimerWheel(minutes: $minutes, range: Self.minutesRange, interval: Self.minutesInterval)
            .frame(height: 128)
            .clipShape(.rect(cornerRadius: 16))
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 28)
    }

    private var startButton: some View {
        Button(action: start) {
            Text("Start my session")
                .font(font(17, .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.brand, in: .capsule)
        }
        .buttonStyle(.plain)
        .opacity(canStart ? 1 : 0.4)
        .disabled(!canStart)
        .padding(.horizontal, 28)
    }

    // MARK: Helpers

    private static let guide = Color(white: 0x97 / 255).opacity(0.15)

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
        .system(size: size * scale, weight: weight)
    }
}

/// The time wheel of the Clock app's alarm editor: two zero-padded columns (hours, minutes) that loop, with the rounded selection band.
/// It is `UIDatePicker` in time mode with a 24-hour locale, read as a duration (00:45 = 45 minutes).
/// SwiftUI's `DatePicker` has no minute interval, so the UIKit control is wrapped here.
///
/// The wheel loops through 00:00 and 23:45, so it can stop outside `range`. `minutes` follows it at once (the start button
/// checks the range) and the wheel returns to the nearest end of the range half a second after it stops. The picker's own
/// minimum and maximum are not used: they hide the value from `valueChanged` while the wheel rests outside the range.
struct TimerWheel: UIViewRepresentable {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let interval: Int

    /// Midnight UTC: the picker works on a fixed day in UTC, so a duration never meets a time-zone or daylight-saving change.
    private static let midnight = Date(timeIntervalSinceReferenceDate: 0)
    private static let utc = TimeZone(secondsFromGMT: 0)!
    private static let minutesPerDay = 24 * 60

    private static func date(_ minutes: Int) -> Date { midnight.addingTimeInterval(TimeInterval(minutes * 60)) }

    /// The end of the range closest to `minutes`, going around midnight.
    static func nearestInRange(_ minutes: Int, in range: ClosedRange<Int>) -> Int {
        if range.contains(minutes) { return minutes }
        let toUpper = abs(minutes - range.upperBound)
        let toLower = min(abs(minutes - range.lowerBound), minutesPerDay - abs(minutes - range.lowerBound))
        return toUpper < toLower ? range.upperBound : range.lowerBound
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "en_GB")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.utc
        picker.calendar = calendar
        picker.timeZone = Self.utc
        picker.minuteInterval = interval
        picker.date = Self.date(minutes)
        picker.accessibilityIdentifier = "focusTimer"
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        if Coordinator.minutes(of: picker) != minutes { picker.setDate(Self.date(minutes), animated: false) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIDatePicker, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 320, height: proposal.height ?? 128)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: TimerWheel
        private var settling: Task<Void, Never>?

        init(_ parent: TimerWheel) { self.parent = parent }

        static func minutes(of picker: UIDatePicker) -> Int {
            Int((picker.date.timeIntervalSince(TimerWheel.midnight) / 60).rounded())
        }

        @objc func changed(_ picker: UIDatePicker) {
            let chosen = Self.minutes(of: picker)
            parent.minutes = chosen
            settling?.cancel()
            guard !parent.range.contains(chosen) else { return }
            settling = Task { [weak picker] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let picker else { return }
                let target = TimerWheel.nearestInRange(chosen, in: parent.range)
                picker.setDate(TimerWheel.date(target), animated: true)
                parent.minutes = target
            }
        }
    }
}
