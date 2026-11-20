import SwiftUI

/// The logo of Sketch Page 5: four concentric rings, more opaque toward the centre.
/// Its colour is the phase of the session (blue ready, orange focus, light blue break).
/// The rings breathe in a slow wave from the centre outward and light up while a long press charges.
/// Text in the centre is measured: the rings move outward and thin out so they never touch it,
/// and spring back to the Page 5 proportions when it goes.
struct StateRing<Center: View>: View {
    var scale: CGFloat
    /// The phase colour; the brand blue when nil.
    var tint: Color?
    /// 0...1: the long press charging; the rings light up one by one from the centre.
    var charge: Double
    var side: CGFloat
    let center: Center

    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var centerSize = CGSize.zero

    init(scale: CGFloat = 1, tint: Color? = nil, charge: Double = 0, side: CGFloat = 240,
         @ViewBuilder center: () -> Center) {
        self.scale = scale
        self.tint = tint
        self.charge = charge
        self.side = side
        self.center = center()
    }

    var body: some View {
        let size = side * scale
        let geometry = LogoGeometry(size: size, clearance: centerSize == .zero ? 0 : hypot(centerSize.width, centerSize.height) / 2 + 8)
        ZStack {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduced)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        // From the centre (k = 0) outward: the wave and the charge both travel outward.
                        let k = Double(3 - index)
                        let wave = reduced ? 0 : sin(time * 1.4 - k * 0.9)
                        let lit = min(1, max(0, charge * 4 - k))
                        let base = LogoGeometry.opacities[index]
                        Annulus(radius: geometry.radius(index), width: geometry.stroke)
                            .fill(tint ?? .brand, style: FillStyle(eoFill: true))
                            .opacity((base + (1 - base) * lit) * (0.86 + 0.14 * wave))
                            .scaleEffect(1 + 0.012 * wave + 0.035 * lit)
                    }
                }
                .animation(reduced ? nil : .spring(duration: 0.5, bounce: 0.3), value: geometry.spread)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            // A ZStack still exists (size zero) when the centre is empty, so the rings close back.
            ZStack { center }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { centerSize = $0 }
        }
    }
}

extension StateRing where Center == EmptyView {
    init(scale: CGFloat = 1, tint: Color? = nil, charge: Double = 0, side: CGFloat = 240) {
        self.init(scale: scale, tint: tint, charge: charge, side: side) { EmptyView() }
    }
}

/// Ring radii for a logo of `size`, pushed outward to leave `clearance` (a radius) free in the centre.
private struct LogoGeometry {
    /// Page 5 icon: ring diameters 54, 44, 33, 23 and a 4 pt stroke, in a 58 pt box (outer ring plus stroke).
    static let diameters: [CGFloat] = [54, 44, 33, 23]
    static let opacities: [Double] = [0.18, 0.30, 0.50, 0.80]
    static let box: CGFloat = 58

    let size: CGFloat
    /// 1 = Page 5 proportions; smaller = rings pushed toward the outer one and thinner.
    let spread: CGFloat

    init(size: CGFloat, clearance: CGFloat) {
        self.size = size
        let outer = size * Self.diameters[0] / Self.box / 2
        let inner = size * Self.diameters[3] / Self.box / 2
        let stroke = size * 4 / Self.box
        // Inner edge = outer − spread × (outer − inner + stroke / 2) must reach the clearance.
        let fit = (outer - clearance) / (outer - inner + stroke / 2)
        spread = min(1, max(0.25, fit))
    }

    var stroke: CGFloat { size * 4 / Self.box * spread }

    func radius(_ index: Int) -> CGFloat {
        let outer = size * Self.diameters[0] / Self.box / 2
        let own = size * Self.diameters[index] / Self.box / 2
        return outer - (outer - own) * spread
    }
}

/// A ring as a filled band, so radius and thickness both animate.
private struct Annulus: Shape {
    var radius: CGFloat
    var width: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, width) }
        set { radius = newValue.first; width = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius - width / 2, y: center.y - radius - width / 2,
                                   width: 2 * radius + width, height: 2 * radius + width))
        path.addEllipse(in: CGRect(x: center.x - radius + width / 2, y: center.y - radius + width / 2,
                                   width: 2 * radius - width, height: 2 * radius - width))
        return path
    }
}

extension Color {
    /// Light and dark variants of one colour.
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    /// Logo blue, the "ready" phase (#1255B2). In dark mode a lighter blue, readable on black.
    static let brand = adaptive(0x1255B2, 0x4C88E0)
    /// Text colour.
    static let ink = adaptive(0x14142B, 0xF2F2F7)
    /// Page background.
    static let canvas = adaptive(0xFFFFFF, 0x000000)
    /// Grouped background, behind cards.
    static let surface = adaptive(0xF2F4F8, 0x000000)
    /// Cards and panels on `surface`.
    static let card = adaptive(0xFFFFFF, 0x1C1C1E)
    /// Logo orange (#E77614): the focus phase. Fill only.
    static let focus = adaptive(0xE77614, 0xE77614)
    /// Logo light blue: the break phase (first row of Page 5 in light, second row in dark).
    static let rest = adaptive(0x82B0F0, 0x78A8EB)
    /// Blue for text in the break phase.
    static let restText = adaptive(0x3B6585, 0xA9C8F2)
    /// Orange for text (#C25400 on white, 4.6:1).
    static let focusText = adaptive(0xC25400, 0xF59A4A)
}

#Preview {
    StateRing(charge: 0.5) {
        Text("120").font(.largeTitle.bold())
    }
}
