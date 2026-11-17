import SwiftUI

/// The ring from the Sketch design. Static for now: the animation plugs in here.
struct StateRing: View {
    enum Phase {
        case checkIn, focus, rest

        var color: Color {
            switch self {
            case .checkIn: .brand
            case .focus: .orange
            case .rest: .cyan
            }
        }
    }

    let phase: Phase

    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                Ellipse()
                    .strokeBorder(phase.color.opacity(0.35), lineWidth: 20)
                    .scaleEffect(x: 1, y: 0.9)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityHidden(true)
    }
}

extension Color {
    /// The Sketch blue (#3062A4). 6.4:1 against white text, so use it as a fill, not as text on dark backgrounds.
    static let brand = Color(red: 48 / 255, green: 98 / 255, blue: 164 / 255)
}

#Preview {
    StateRing(phase: .checkIn)
}
