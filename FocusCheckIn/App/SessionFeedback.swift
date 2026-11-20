import Foundation

/// The answer the engine learns from. The raw values are stored codes: do not rename them.
enum SessionFeedback: String, Identifiable {
    case rightLength, couldContinue, tooLong, tired, taskFinished, interrupted
    // Added 2026-11-20 for the Sketch end screens; the first six codes are unchanged.
    case couldNotFocus, stressed, onPhone, skipped

    /// "Was the session the right length?" in "Session End – Completed".
    static let atDeadline: [Self] = [.couldContinue, .rightLength, .tooLong]
    /// "What made you stop?" in "Session End – Stopped early", in the Sketch order.
    static let stoppedEarly: [Self] = [.tired, .couldNotFocus, .onPhone, .interrupted, .stressed, .taskFinished]

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .couldContinue: "Too short"
        case .rightLength: "Just right"
        case .tooLong: "Too long"
        case .tired: "Too tired"
        case .couldNotFocus: "Couldn’t focus"
        case .onPhone: "On my phone"
        case .interrupted: "Interrupted"
        case .stressed: "Felt stressed"
        case .taskFinished: "Task finished"
        case .skipped: "Skip"
        }
    }

    var systemImage: String {
        switch self {
        case .couldContinue: "minus"
        case .rightLength: "scope"
        case .tooLong: "arrow.right.to.line"
        case .tired: "battery.25percent"
        case .couldNotFocus: "circle.dotted"
        case .onPhone: "iphone"
        case .interrupted: "person"
        case .stressed: "waveform.path"
        case .taskFinished: "checkmark.circle"
        case .skipped: "forward"
        }
    }

    /// 1 = the length was manageable, 0 = it was not, nil = the answer says nothing about the length.
    var outcome: Double? {
        switch self {
        case .rightLength, .couldContinue: 1
        case .tooLong, .tired, .couldNotFocus, .stressed: 0
        case .taskFinished, .interrupted, .onPhone, .skipped: nil
        }
    }
}

/// "Could you keep going?" — stored with the session, not used by the engine.
enum KeepGoingAnswer: String, CaseIterable, Identifiable {
    case easily, littleMore, done
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self {
        case .easily: "Yes, easily"
        case .littleMore: "A little more"
        case .done: "No, I’m done"
        }
    }
    var systemImage: String {
        switch self {
        case .easily: "battery.100percent"
        case .littleMore: "battery.50percent"
        case .done: "battery.0percent"
        }
    }
}

/// "Did you need a break along the way?" — stored with the session, not used by the engine.
enum BreakAnswer: String, CaseIterable, Identifiable {
    case inFlow, tookBreak, pushedThrough
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self {
        case .inFlow: "In the flow"
        case .tookBreak: "Took a break"
        case .pushedThrough: "Pushed through"
        }
    }
    var systemImage: String {
        switch self {
        case .inFlow: "water.waves"
        case .tookBreak: "pause"
        case .pushedThrough: "chevron.forward.2"
        }
    }
}
