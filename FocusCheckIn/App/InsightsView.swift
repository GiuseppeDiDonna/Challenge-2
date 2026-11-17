import SwiftUI

struct InsightsView: View {
    let history: FocusHistory

    var body: some View {
        NavigationStack {
            Group {
                if let scores = history.pilotScores {
                    Form {
                        DisclosureGroup("Pilot check") {
                            LabeledContent("Sessions scored", value: scores.count.formatted())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Sessions scored")
                                .accessibilityValue(scores.count.formatted())
                                .accessibilityIdentifier("pilotSessionCount")
                            LabeledContent("Brier · Starting model", value: scores.base.formatted(.number.precision(.fractionLength(3))))
                            LabeledContent("Brier · Length and energy", value: scores.personal.formatted(.number.precision(.fractionLength(3))))
                            LabeledContent("Brier · With sleep", value: scores.withSleep.formatted(.number.precision(.fractionLength(3))))
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No insights yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Finish a focus session and answer the question at the end to see your data here.")
                    )
                }
            }
            .navigationTitle("Insights")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}
