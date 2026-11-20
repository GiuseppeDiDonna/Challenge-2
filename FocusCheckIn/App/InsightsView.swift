import Charts
import SwiftUI

struct InsightsView: View {
    let history: FocusHistory

    private var chartData: InsightChartData {
        InsightChartData(sessions: history.sessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A clearer view of your focus routine.")
                    .font(.subheadline)
                    .foregroundStyle(Color.ink.opacity(0.65))
                    .padding(.horizontal, 4)

                dailyFocusCard
                plannedAndActualCard
                sleepAndFocusCard
                pilotCheck

                Text("Charts summarize completed sessions. The sleep chart shows personal history, not cause and effect.")
                    .font(.footnote)
                    .foregroundStyle(Color.ink.opacity(0.55))
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("insightsFootnote")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color.surface.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Insights")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    private var dailyFocusCard: some View {
        chartCard(
            title: "Daily focus time",
            subtitle: "Minutes completed each day · last 14 days",
            identifier: "dailyFocusChart"
        ) {
            if chartData.completedSessionCount == 0 {
                emptyChart("Finish a focus session to start your history.", systemImage: "clock")
            } else {
                Chart(chartData.daily) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Minutes", point.actualMinutes)
                    )
                    .foregroundStyle(Color.brand.opacity(0.10))

                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Minutes", point.actualMinutes)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("Minutes", point.actualMinutes)
                    )
                    .foregroundStyle(Color.brand)
                    .symbolSize(24)
                }
                .chartXScale(domain: chartData.daily.first!.date...chartData.daily.last!.date)
                .chartYScale(domain: 0...dailyMaximum)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.ink.opacity(0.05))
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                }
                .accessibilityLabel("Daily focus minutes")
                .accessibilityValue("Minutes completed on each of the last 14 days")
                .frame(height: 190)
            }
        }
    }

    private var plannedAndActualCard: some View {
        chartCard(
            title: "Planned vs. focused",
            subtitle: "Weekly total for sessions that have ended",
            identifier: "plannedActualChart"
        ) {
            if chartData.completedSessionCount == 0 {
                emptyChart("Planned and completed time will appear here.", systemImage: "chart.bar.xaxis")
            } else {
                Chart {
                    ForEach(chartData.weekly) { point in
                        BarMark(
                            x: .value("Week", point.date, unit: .weekOfYear),
                            y: .value("Minutes", point.plannedMinutes)
                        )
                        .foregroundStyle(by: .value("Time", "Planned"))
                        .position(by: .value("Time", "Planned"))

                        BarMark(
                            x: .value("Week", point.date, unit: .weekOfYear),
                            y: .value("Minutes", point.actualMinutes)
                        )
                        .foregroundStyle(by: .value("Time", "Focused"))
                        .position(by: .value("Time", "Focused"))
                    }
                }
                .chartForegroundStyleScale(
                    domain: ["Planned", "Focused"],
                    range: [Color.brand.opacity(0.32), Color.brand]
                )
                .chartLegend(position: .top, alignment: .leading, spacing: 12)
                .chartXScale(domain: chartData.weekly.first!.date...chartData.weekly.last!.date)
                .chartYScale(domain: 0...weeklyMaximum)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisGridLine().foregroundStyle(Color.ink.opacity(0.05))
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                }
                .accessibilityLabel("Planned and completed focus minutes by week")
                .frame(height: 220)
            }
        }
    }

    private var sleepAndFocusCard: some View {
        chartCard(
            title: "Sleep and focus",
            subtitle: "Sleep recorded before a session and time focused",
            identifier: "sleepFocusChart"
        ) {
            if chartData.sessionsNeededToUnlockSleepChart > 0 {
                lockedSleepChart
            } else {
                sleepChart
            }
        }
    }

    @ViewBuilder
    private var pilotCheck: some View {
        if let scores = history.pilotScores {
            DisclosureGroup("Pilot check") {
                VStack(spacing: 10) {
                    LabeledContent("Sessions scored", value: scores.count.formatted())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Sessions scored")
                        .accessibilityValue(scores.count.formatted())
                        .accessibilityIdentifier("pilotSessionCount")
                    LabeledContent("Brier · Starting model", value: scores.base.formatted(.number.precision(.fractionLength(3))))
                    LabeledContent("Brier · Length and energy", value: scores.personal.formatted(.number.precision(.fractionLength(3))))
                    LabeledContent("Brier · With sleep", value: scores.withSleep.formatted(.number.precision(.fractionLength(3))))
                }
                .font(.footnote)
                .padding(.top, 10)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.ink)
            .padding(16)
            .background(Color.card, in: .rect(cornerRadius: 18))
        }
    }

    private var lockedSleepChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 40, height: 40)
                    .background(Color.brand.opacity(0.09), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("A few more sessions unlock this chart")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text("We need 5 completed sessions with sleep data and a clear check-out to make this comparison useful.")
                        .font(.footnote)
                        .foregroundStyle(Color.ink.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ProgressView(value: Double(chartData.sleep.count), total: Double(InsightChartData.sleepUnlockThreshold))
                .tint(Color.brand)

            HStack {
                Text("\(chartData.sleep.count) of \(InsightChartData.sleepUnlockThreshold) sessions")
                    .accessibilityIdentifier("sleepUnlockProgress")
                Spacer(minLength: 8)
                let remaining = chartData.sessionsNeededToUnlockSleepChart
                Text(remaining == 1 ? "1 more to go" : "\(remaining) more to go")
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("sleepSessionsRemaining")
            }
            .font(.caption)
            .foregroundStyle(Color.ink.opacity(0.75))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(chartData.sleep) { point in
                    if let sleepHours = point.sleepHours, let manageable = point.outcomeWasManageable {
                        if manageable {
                            PointMark(
                                x: .value("Sleep before session", sleepHours),
                                y: .value("Focused minutes", point.actualMinutes)
                            )
                            .symbol(.circle)
                            .foregroundStyle(Color.brand)
                            .symbolSize(75)
                        } else {
                            PointMark(
                                x: .value("Sleep before session", sleepHours),
                                y: .value("Focused minutes", point.actualMinutes)
                            )
                            .symbol(.cross)
                            .foregroundStyle(Color.orange)
                            .symbolSize(75)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...sleepMaximum)
            .chartYScale(domain: 0...sleepFocusMaximum)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 5))
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
            }
            .chartXAxisLabel("Sleep in the previous 24 hours")
            .chartYAxisLabel("Focused minutes")
            .accessibilityLabel("Sleep duration compared with actual focus minutes")
            .frame(height: 210)

            HStack(spacing: 16) {
                legendItem(symbol: "circle.fill", color: .brand, title: "Manageable")
                legendItem(symbol: "xmark", color: .orange, title: "Felt difficult")
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
        }
    }

    private var dailyMaximum: Double {
        max(60, (chartData.daily.map(\.actualMinutes).max() ?? 0) * 1.15)
    }

    private var weeklyMaximum: Double {
        max(60, (chartData.weekly.map { max($0.plannedMinutes, $0.actualMinutes) }.max() ?? 0) * 1.15)
    }

    private var sleepMaximum: Double {
        max(8, (chartData.sleep.compactMap(\.sleepHours).max() ?? 0) + 1)
    }

    private var sleepFocusMaximum: Double {
        max(60, (chartData.sleep.map(\.actualMinutes).max() ?? 0) * 1.15)
    }

    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color.ink.opacity(0.6))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func emptyChart(_ message: String, systemImage: String) -> some View {
        ContentUnavailableView(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(Color.ink.opacity(0.65))
            .frame(height: 150)
    }

    private func legendItem(symbol: String, color: Color, title: String) -> some View {
        Label {
            Text(title).foregroundStyle(Color.ink.opacity(0.75))
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }
}
