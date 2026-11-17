import SwiftUI

@main
struct FocusCheckInApp: App {
    @State private var history = makeHistory()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Focus", systemImage: "target") {
                    FocusCheckInView(history: history)
                }
                Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") {
                    InsightsView(history: history)
                }
                Tab {
                    ContentUnavailableView("Block", systemImage: "lock", description: Text("Coming soon"))
                } label: {
                    // The design draws the lock as an outline, also when it is not selected.
                    Label("Block", systemImage: "lock").environment(\.symbolVariants, .none)
                }
            }
            .tint(.brand)
            // The Sketch design only exists in light mode; dark variants come from the designers.
            .preferredColorScheme(.light)
        }
    }

    private static func makeHistory() -> FocusHistory {
        let base = URL.applicationSupportDirectory.appending(path: "FocusCheckIn", directoryHint: .isDirectory)
        #if DEBUG
        if let value = UserDefaults.standard.string(forKey: "focusTestHistory"),
           let id = UUID(uuidString: value) {
            let history = FocusHistory(directory: base.appending(path: id.uuidString, directoryHint: .isDirectory))
            if UserDefaults.standard.bool(forKey: "focusTestNearDeadline"), history.sessions.isEmpty {
                history.start(FocusSession(startedAt: .now.addingTimeInterval(-292), plannedMinutes: 5,
                                           energy: .medium, sleep: nil, sleepDeviation: nil, forecast: nil))
            }
            return history
        }
        #endif
        return FocusHistory(directory: base)
    }
}
