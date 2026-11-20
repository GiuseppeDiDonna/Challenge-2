import Foundation
import SwiftData

@Model
final class FocusSession {
    @Attribute(.unique) var sessionID: UUID
    var startedAt: Date
    var plannedMinutes: Int
    var energyCode: String
    var sleepHours: Double?
    var sleepNight: String?
    var sleepDeviation: Double?
    var endedAt: Date?
    var actualMinutes: Double?
    var feedbackCode: String?
    var feedbackAt: Date?
    /// The two extra questions of "Session End – Completed" (`KeepGoingAnswer`, `BreakAnswer`); the engine does not read them.
    var keepGoingCode: String?
    var breakCode: String?
    /// Seconds spent in finished in-session breaks: the deadline moves by this much and they are not focus time.
    var pausedSeconds: Double?
    /// Start of the in-session break in progress.
    var pausedAt: Date?
    var baseProbability: Double?
    var personalProbability: Double?
    var sleepProbability: Double?

    init(startedAt: Date, plannedMinutes: Int, energy: FocusEnergy, sleep: SleepObservation?, sleepDeviation: Double?,
         forecast: Personalization.Forecast?) {
        self.sessionID = UUID()
        self.startedAt = startedAt
        self.plannedMinutes = plannedMinutes
        energyCode = energy.rawValue
        sleepHours = sleep?.hours
        sleepNight = sleep?.night
        self.sleepDeviation = sleepDeviation
        baseProbability = forecast?.base
        personalProbability = forecast?.personal
        sleepProbability = forecast?.withSleep
    }

    var deadline: Date { deadline(at: .now) }

    /// The countdown stands still during a break: the deadline moves with it.
    func deadline(at now: Date) -> Date {
        let ongoing = pausedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return startedAt.addingTimeInterval(Double(plannedMinutes) * 60 + (pausedSeconds ?? 0) + ongoing)
    }

    /// Focus time so far, breaks excluded.
    func focusedMinutes(at now: Date) -> Double {
        let ongoing = pausedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return max(0, now.timeIntervalSince(startedAt) - (pausedSeconds ?? 0) - ongoing) / 60
    }

    var feedback: SessionFeedback? {
        feedbackCode.flatMap(SessionFeedback.init(rawValue:))
    }

    var feedbackChoices: [SessionFeedback] {
        guard let endedAt else { return [] }
        return endedAt < deadline ? SessionFeedback.stoppedEarly : SessionFeedback.atDeadline
    }
}

/// A break, during a session (Pause) or after it. Kept on the device as data for a future model that suggests breaks
/// ("Segnali per il modello che suggerisce le pause"): asking for a break at a given minute is the label.
@Model
final class FocusBreak {
    var sessionID: UUID
    var startedAt: Date
    var endedAt: Date?
    var duringSession: Bool
    /// Minutes of the session already focused when the break started.
    var minuteInSession: Double
    /// Focus since the previous break in the same session: the suggestion is a quarter of it.
    var focusSinceLastBreak: Double
    var suggestedMinutes: Int
    /// The length on the timer, changed by turning the ring.
    var plannedMinutes: Int
    var energyCode: String
    var sleepHours: Double?
    var sleepDeviation: Double?

    init(session: FocusSession, startedAt: Date, duringSession: Bool, minuteInSession: Double, focusSinceLastBreak: Double) {
        sessionID = session.sessionID
        self.startedAt = startedAt
        self.duringSession = duringSession
        self.minuteInSession = minuteInSession
        self.focusSinceLastBreak = focusSinceLastBreak
        let suggested = Self.suggestedMinutes(afterFocus: focusSinceLastBreak)
        suggestedMinutes = suggested
        plannedMinutes = suggested
        energyCode = session.energyCode
        sleepHours = session.sleepHours
        sleepDeviation = session.sleepDeviation
    }

    var ends: Date { startedAt.addingTimeInterval(Double(plannedMinutes) * 60) }

    /// A quarter of the focus time, between 3 and 15 minutes: the 24 + 6 and 12 + 3 schedules of Biwer et al. 2023;
    /// breaks of 10 minutes or less help vigour and fatigue (Albulescu et al. 2022). Not a learned value yet.
    static func suggestedMinutes(afterFocus minutes: Double) -> Int {
        min(15, max(3, Int((minutes / 4).rounded())))
    }
}
