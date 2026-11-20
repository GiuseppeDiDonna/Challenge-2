import Foundation

/// The raw values are the codes the model and the stored sessions use: do not rename them.
enum FocusEnergy: String, CaseIterable, Identifiable {
    case low = "bassa"
    case medium = "media"
    case high = "alta"

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .low: "Low"
        case .medium: "Steady"
        case .high: "Charged"
        }
    }

    var caption: LocalizedStringResource {
        switch self {
        case .low: "Take it easy"
        case .medium: "Ready to work"
        case .high: "Full power"
        }
    }
}
