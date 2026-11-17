import Foundation

enum SessionFeedback: String, Identifiable {
    case rightLength, couldContinue, tooLong, tired, taskFinished, interrupted

    static let atDeadline: [Self] = [.rightLength, .couldContinue, .tooLong]
    static let stoppedEarly: [Self] = [.tired, .taskFinished, .interrupted]

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .rightLength: "The length felt right"
        case .couldContinue: "I could have kept going"
        case .tooLong: "It felt too long"
        case .tired: "I felt tired"
        case .taskFinished: "I finished the task"
        case .interrupted: "Something came up"
        }
    }

    var outcome: Double? {
        switch self {
        case .rightLength, .couldContinue: 1
        case .tooLong, .tired: 0
        case .taskFinished, .interrupted: nil
        }
    }
}
