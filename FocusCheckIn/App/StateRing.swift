import SwiftUI

/// The ring from the Sketch design ("State Ring", 202×229 pt), exported from Sketch at 3x.
/// Static for now: the animation plugs in here.
struct StateRing: View {
    var scale: CGFloat = 1

    var body: some View {
        Group {
            if let image = Self.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle().strokeBorder(Color.brand.opacity(0.5), lineWidth: 40)
            }
        }
        .frame(width: 202 * scale, height: 229 * scale)
        .accessibilityHidden(true)
    }

    private static let image = Bundle.main.path(forResource: "StateRing@3x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
}

extension Color {
    /// The Sketch blue (#3062A4). 6.4:1 against white text, so use it as a fill, not as text on dark backgrounds.
    static let brand = Color(red: 0x30 / 255, green: 0x62 / 255, blue: 0xA4 / 255)
    /// Text colour of the Sketch design (#14142B).
    static let ink = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x2B / 255)
    /// Card and time-box fill (#F2F4F8).
    static let surface = Color(red: 0xF2 / 255, green: 0xF4 / 255, blue: 0xF8 / 255)
}

#Preview {
    StateRing()
}
