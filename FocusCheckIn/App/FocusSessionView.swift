import SwiftUI

struct FocusSessionView: View {
    let session: FocusSession
    let history: FocusHistory

    var body: some View {
        if let actual = session.actualMinutes {
            Section(session.feedbackChoices == SessionFeedback.atDeadline ? "How was the length?" : "Why did you stop early?") {
                LabeledContent("Focus time", value: actual.formatted(.number.precision(.fractionLength(0...1))) + " min")
                ForEach(session.feedbackChoices) { feedback in
                    Button(feedback.title) {
                        history.record(feedback, for: session)
                    }
                }
            }
        } else {
            Section("Session in progress") {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let remaining = Int(max(0, session.deadline.timeIntervalSince(timeline.date)).rounded(.up))
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                        .font(.largeTitle.monospacedDigit())
                        .accessibilityLabel("Time remaining")
                        .accessibilityValue(Duration.seconds(remaining).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                        .onChange(of: remaining, initial: true) {
                            if remaining == 0 && !history.failed {
                                history.finish(session)
                            }
                        }
                }
                Button("End early") {
                    history.finish(session)
                }
            }
        }
    }
}
