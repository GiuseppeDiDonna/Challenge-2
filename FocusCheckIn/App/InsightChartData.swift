import Foundation

struct InsightChartData {
    static let sleepUnlockThreshold = 5

    struct Point: Identifiable {
        let id: String
        let date: Date
        let plannedMinutes: Double
        let actualMinutes: Double
        let sleepHours: Double?
        let outcomeWasManageable: Bool?
    }

    let completedSessionCount: Int
    let daily: [Point]
    let weekly: [Point]
    let sleep: [Point]

    var sessionsNeededToUnlockSleepChart: Int {
        max(0, Self.sleepUnlockThreshold - sleep.count)
    }

    init(sessions: [FocusSession], now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        let completed = sessions.compactMap { session -> (session: FocusSession, endedAt: Date, actual: Double)? in
            guard let endedAt = session.endedAt,
                  let actual = session.actualMinutes,
                  actual > 0 else { return nil }
            return (session, endedAt, actual)
        }
        completedSessionCount = completed.count

        var dailyTotals: [Date: Double] = [:]
        for item in completed {
            let day = calendar.startOfDay(for: item.endedAt)
            dailyTotals[day, default: 0] += item.actual
        }
        let today = calendar.startOfDay(for: now)
        daily = (0..<14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 13, to: today) else { return nil }
            return Point(id: String(Int(day.timeIntervalSince1970)), date: day, plannedMinutes: 0,
                         actualMinutes: dailyTotals[day, default: 0], sleepHours: nil, outcomeWasManageable: nil)
        }

        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let weekStarts = (0..<8).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0 - 7, to: currentWeek)
        }
        var weeklyTotals: [Date: (planned: Double, actual: Double)] = [:]
        for item in completed {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: item.endedAt)?.start else { continue }
            weeklyTotals[week, default: (0, 0)].planned += Double(item.session.plannedMinutes)
            weeklyTotals[week, default: (0, 0)].actual += item.actual
        }
        weekly = weekStarts.map { week in
            let totals = weeklyTotals[week, default: (0, 0)]
            return Point(id: String(Int(week.timeIntervalSince1970)), date: week,
                         plannedMinutes: totals.planned, actualMinutes: totals.actual,
                         sleepHours: nil, outcomeWasManageable: nil)
        }

        sleep = completed.compactMap { item in
            guard let hours = item.session.sleepHours, hours > 0,
                  let outcome = item.session.feedback?.outcome else { return nil }
            return Point(id: item.session.sessionID.uuidString, date: item.session.startedAt,
                         plannedMinutes: Double(item.session.plannedMinutes), actualMinutes: item.actual,
                         sleepHours: hours, outcomeWasManageable: outcome >= 0.5)
        }
    }
}
