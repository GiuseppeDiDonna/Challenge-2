import CoreML
import SwiftUI

struct FocusCheckInView: View {
    let history: FocusHistory
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @AppStorage("readsSleepFromHealth") private var readsSleepFromHealth = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("askedForName") private var askedForName = false
    @State private var checkingIn = false
    @State private var minutes = 45
    @State private var energy: FocusEnergy?
    @State private var starting = false
    @State private var askingName = false
    @State private var nameDraft = ""
    @State private var sleepReader = SleepReader()
    @State private var classifier: Result<FocusDurationClassifier, any Error>?

    var body: some View {
        Group {
            if history.active != nil || history.failed {
                sessionForm
            } else {
                HomeScreen(greeting: greeting, period: period, checkingIn: $checkingIn, energy: $energy, minutes: $minutes,
                           canStart: energy != nil && !starting && HomeScreen.minutesRange.contains(minutes), start: beginSession)
            }
        }
        .task {
            refreshHistory()
            if userName.isEmpty && !askedForName { askingName = true }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            refreshHistory()
        }
        .onChange(of: history.active?.sessionID) { checkingIn = false }
        .alert("What’s your name?", isPresented: $askingName) {
            TextField("Name", text: $nameDraft)
            Button("Save") {
                userName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                askedForName = true
            }
            Button("Not now", role: .cancel) { askedForName = true }
        } message: {
            Text("It appears in your greeting and stays on this iPhone.")
        }
    }

    /// A session in progress, or its feedback. Still the plain list: the full-screen session is the next slice.
    private var sessionForm: some View {
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
                }
            }
            .navigationTitle(greeting)
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    private var greeting: String {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = switch period {
        case "morning": "Good morning"
        case "afternoon": "Good afternoon"
        default: "Good evening"
        }
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var period: String {
        switch calendar.component(.hour, from: .now) {
        case 5..<12: "morning"
        case 12..<18: "afternoon"
        default: "evening"
        }
    }

    private func refreshHistory() {
        history.reload()
        if let session = history.active, session.endedAt == nil, session.deadline <= .now {
            history.finish(session)
        }
    }

    private func beginSession() {
        guard !starting, let energy, HomeScreen.minutesRange.contains(minutes) else { return }
        let minutes = minutes
        starting = true
        Task {
            defer { starting = false }
            let start = Date.now
            var sleep: SleepObservation?
            if readsSleepFromHealth, sleepReader.isAvailable {
                sleep = try? await sleepReader.sleep(before: start)
            }
            let deviation = history.sleepDeviation(for: sleep, before: start)
            let prediction = try? forecast(minutes: minutes, energy: energy, deviation: deviation)
            history.start(FocusSession(startedAt: start, plannedMinutes: minutes, energy: energy,
                                       sleep: sleep, sleepDeviation: deviation, forecast: prediction))
            if history.active != nil { self.energy = nil }
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
