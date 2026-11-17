import CoreML
import SwiftUI

struct FocusCheckInView: View {
    private enum Field: Hashable { case duration, sleep }

    let history: FocusHistory
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("readsSleepFromHealth") private var readsSleepFromHealth = false
    @State private var minutes: Int? = 45
    @State private var energy: FocusEnergy?
    @State private var manualSleepHours: Double?
    @State private var healthSleep: SleepObservation?
    @State private var sleepReader = SleepReader()
    @State private var requestingHealth = false
    @State private var healthMessage: LocalizedStringResource?
    @State private var starting = false
    @State private var classifier: Result<FocusDurationClassifier, any Error>?
    @State private var estimates: [DurationEstimate] = []
    @State private var predictionFailed = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                if history.failed {
                    Section {
                        Label("Can’t open your local history.", systemImage: "exclamationmark.circle")
                        Button("Try again", action: refreshHistory)
                    }
                }
                if let session = history.active {
                    FocusSessionView(session: session, history: history)
                } else {
                    setup
                    predictions
                    sleep
                }
            }
            .navigationTitle(greeting)
            .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .toolbarTitleDisplayMode(.inlineLarge)
            .listSectionSpacing(.compact)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaBar(edge: .bottom) {
                if history.active == nil {
                    Button(action: beginSession) {
                        Text("Start focus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.brand)
                    .disabled(!hasValidDuration || !hasValidSleep || energy == nil || history.failed || starting || requestingHealth)
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done", action: dismissKeyboard)
                }
            }
        }
        .task {
            refreshHistory()
            await refreshSleep()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            refreshHistory()
            Task { await refreshSleep() }
        }
        .onChange(of: minutes, updateEstimates)
        .onChange(of: energy, updateEstimates)
        .onChange(of: manualSleepHours, updateEstimates)
        .onChange(of: history.active?.sessionID, updateEstimates)
    }

    private var greeting: LocalizedStringResource {
        switch calendar.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private var setup: some View {
        Group {
            Section {
                StateRing(phase: .checkIn)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            Section("How’s your energy?") {
                // Side by side normally; stacked when the text is too large for three columns.
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())) {
                    ForEach(FocusEnergy.allCases) { level in
                        let dot = switch level {
                        case .low: 8.0
                        case .medium: 14.0
                        case .high: 20.0
                        }
                        Button {
                            energy = level
                        } label: {
                            VStack {
                                Circle()
                                    .frame(width: dot, height: dot)
                                    .frame(height: 24)
                                Text(level.title)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .foregroundStyle(energy == level ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                            .background(energy == level ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.fill.tertiary),
                                        in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(energy == level ? .isSelected : [])
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section("Focus for") {
                Stepper {
                    HStack {
                        TextField("Minutes", value: $minutes, format: .number.grouping(.never), prompt: Text(verbatim: "0"))
                            .keyboardType(.numberPad)
                            .font(.title.monospacedDigit())
                            .fixedSize()
                            .focused($focusedField, equals: .duration)
                            .accessibilityIdentifier("plannedMinutes")
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                } onIncrement: {
                    stepMinutes(by: 5)
                } onDecrement: {
                    stepMinutes(by: -5)
                }
                if let minutes, let energy, history.suggestsExtension(minutes: minutes, energy: energy) {
                    Button("Try 10 more minutes") { self.minutes = minutes + 10 }
                }
            }
        }
        .disabled(starting)
    }

    private var sleep: some View {
        Section("Sleep (optional)") {
            TextField("Hours of sleep", value: $manualSleepHours, format: .number)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .sleep)
            if !hasValidSleep {
                Text("Enter a value between 0 and 24 hours.")
                    .foregroundStyle(.secondary)
            } else if let healthSleep, manualSleepHours == nil {
                LabeledContent("Sleep from Health", value: healthSleep.hours.formatted(.number.precision(.fractionLength(1))) + " h")
            }
            if sleepReader.isAvailable {
                if readsSleepFromHealth {
                    Button("Stop reading from Health", action: disableHealth)
                } else {
                    Button("Read sleep from Health", action: enableHealth)
                        .disabled(requestingHealth)
                }
                if let healthMessage {
                    Text(healthMessage).foregroundStyle(.secondary)
                }
            }
        }
        .disabled(starting)
    }

    private var predictions: some View {
        Section {
            if !hasValidDuration {
                Text("Enter a length between 5 and 180 minutes.")
                    .foregroundStyle(.secondary)
            } else if energy == nil {
                Text("Pick your energy to see the estimates.")
                    .foregroundStyle(.secondary)
            } else if predictionFailed {
                Label("Can’t calculate the estimate.", systemImage: "exclamationmark.circle")
            } else {
                ForEach(estimates) { estimate in
                    LabeledContent {
                        Text(estimate.probability, format: .percent.precision(.fractionLength(1)))
                            .monospacedDigit()
                    } label: {
                        if estimate.minutes == minutes {
                            Text("\(estimate.minutes) min · Your pick")
                                .bold()
                        } else {
                            Text("\(estimate.minutes) min")
                        }
                    }
                    .accessibilityIdentifier("estimate-\(estimate.minutes)")
                }
            }
        } header: {
            Text("Chance this length is manageable")
        } footer: {
            if history.model.personal != nil {
                Text("Estimates adapted to your history.")
            } else {
                Text("Estimates based on simulated sessions.")
            }
        }
    }

    private func stepMinutes(by step: Int) {
        let range = DurationEstimate.allowedMinutes
        minutes = min(max((minutes ?? 45) + step, range.lowerBound), range.upperBound)
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private var hasValidDuration: Bool {
        guard let minutes else { return false }
        return DurationEstimate.allowedMinutes.contains(minutes)
    }

    private var hasValidSleep: Bool {
        guard let manualSleepHours else { return true }
        return manualSleepHours.isFinite && (0...24).contains(manualSleepHours)
    }

    private func sleepObservation(at date: Date) -> SleepObservation? {
        if let manualSleepHours, hasValidSleep {
            return SleepObservation(hours: manualSleepHours, endingAt: date)
        }
        return readsSleepFromHealth ? healthSleep : nil
    }

    private func enableHealth() {
        guard !requestingHealth else { return }
        requestingHealth = true
        Task {
            defer { requestingHealth = false }
            do {
                try await sleepReader.requestAccess()
                readsSleepFromHealth = true
                await refreshSleep()
            } catch {
                healthMessage = "Can’t access Health. You can enter the hours yourself."
            }
        }
    }

    private func disableHealth() {
        readsSleepFromHealth = false
        healthSleep = nil
        healthMessage = nil
        updateEstimates()
    }

    private func refreshSleep() async {
        guard readsSleepFromHealth, sleepReader.isAvailable else { return }
        let result = try? await sleepReader.sleep(before: .now)
        guard readsSleepFromHealth else { return }
        healthSleep = result
        healthMessage = result == nil ? "No sleep data available." : nil
        updateEstimates()
    }

    private func refreshHistory() {
        history.reload()
        if let session = history.active, session.endedAt == nil, session.deadline <= .now {
            history.finish(session)
        }
        updateEstimates()
    }

    private func beginSession() {
        guard !starting, let minutes, hasValidDuration, hasValidSleep, let energy else { return }
        dismissKeyboard()
        starting = true
        Task {
            defer { starting = false }
            let start = Date.now
            let sleep: SleepObservation?
            if manualSleepHours == nil, readsSleepFromHealth, sleepReader.isAvailable {
                sleep = try? await sleepReader.sleep(before: start)
            } else {
                sleep = sleepObservation(at: start)
            }
            let deviation = history.sleepDeviation(for: sleep, before: start)
            let prediction = try? forecast(minutes: minutes, energy: energy, deviation: deviation)
            history.start(FocusSession(startedAt: start, plannedMinutes: minutes, energy: energy,
                                       sleep: sleep, sleepDeviation: deviation, forecast: prediction))
            if history.active != nil { manualSleepHours = nil }
        }
    }

    private func updateEstimates() {
        estimates = []
        predictionFailed = false
        guard let energy, let minutes, hasValidDuration else { return }

        let now = Date.now
        let deviation = history.sleepDeviation(for: sleepObservation(at: now), before: now)
        do {
            estimates = try DurationEstimate.candidates(around: minutes).map { candidate in
                let prediction = try forecast(minutes: candidate, energy: energy, deviation: deviation)
                return DurationEstimate(minutes: candidate, probability: prediction.withSleep)
            }
        } catch {
            predictionFailed = true
        }
    }

    private func forecast(minutes: Int, energy: FocusEnergy, deviation: Double?) throws -> Personalization.Forecast {
        let loadedClassifier = classifier ?? Result {
            try FocusDurationClassifier(configuration: MLModelConfiguration())
        }
        classifier = loadedClassifier
        let prediction = try loadedClassifier.get().prediction(
            minuti_pianificati: Double(minutes),
            energia_iniziale: energy.rawValue
        )
        guard let probability = prediction.durata_gestibileProbability["si"],
              probability.isFinite, (0...1).contains(probability) else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        return history.model.forecast(base: probability, minutes: minutes, energy: energy, sleepDeviation: deviation)
    }
}
