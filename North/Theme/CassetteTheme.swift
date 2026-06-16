import SwiftUI

/// Cassette-inspired colour palette: warm cream paper, charcoal plastic, magnetic
/// brown tape, brushed-aluminium pickups and a touch of red record-light.
///
/// All colours are defined for both light and dark mode so the cassette feels
/// nostalgic in either appearance.
enum CassettePalette {
    static let cream      = Color(red: 0.96, green: 0.92, blue: 0.84)
    static let paper      = Color(red: 0.99, green: 0.97, blue: 0.91)
    static let charcoal   = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let plastic    = Color(red: 0.20, green: 0.20, blue: 0.22)
    static let aluminium  = Color(red: 0.78, green: 0.78, blue: 0.80)
    static let tape       = Color(red: 0.36, green: 0.21, blue: 0.13)
    static let tapeHL     = Color(red: 0.55, green: 0.36, blue: 0.20)
    static let recordRed  = Color(red: 0.85, green: 0.18, blue: 0.18)
    static let lcdGreen   = Color(red: 0.62, green: 0.78, blue: 0.40)
    static let labelInk   = Color(red: 0.18, green: 0.16, blue: 0.13)

    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.97, green: 0.93, blue: 0.84),
                 Color(red: 0.91, green: 0.85, blue: 0.74)],
        startPoint: .top, endPoint: .bottom
    )

    static let darkBackgroundGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.09, blue: 0.10),
                 Color(red: 0.07, green: 0.06, blue: 0.07)],
        startPoint: .top, endPoint: .bottom
    )
}

/// The user-selectable accent tint applied across the app. Defaults to the
/// classic record-light red so the cassette aesthetic is preserved.
///
/// The first eight cases are flat colours; the final eight are gradients. A tint
/// always exposes a representative solid `color` (used for the global system tint,
/// opacity-based fills and badges) and, for gradient tints, a `gradient`. The
/// `style` property returns the gradient when present, otherwise the flat colour,
/// so prominent fills can show gradients uniformly.
enum AppTint: String, CaseIterable, Identifiable {
    // Flat colours.
    case red, orange, amber, green, teal, blue, plum, magenta
    // Gradients.
    case sunset, lagoon, meadow, candy, mango, grape, aurora, ember

    var id: String { rawValue }

    /// All flat-colour tints, in display order.
    static var solids: [AppTint] { allCases.filter { $0.gradient == nil } }
    /// All gradient tints, in display order.
    static var gradients: [AppTint] { allCases.filter { $0.gradient != nil } }

    /// Representative solid colour. For gradient tints this is the gradient's
    /// dominant (leading) colour.
    var color: Color {
        switch self {
        case .red:     return Color(red: 0.85, green: 0.18, blue: 0.18)
        case .orange:  return Color(red: 0.90, green: 0.45, blue: 0.15)
        case .amber:   return Color(red: 0.85, green: 0.62, blue: 0.16)
        case .green:   return Color(red: 0.20, green: 0.52, blue: 0.30)
        case .teal:    return Color(red: 0.13, green: 0.52, blue: 0.53)
        case .blue:    return Color(red: 0.16, green: 0.40, blue: 0.72)
        case .plum:    return Color(red: 0.45, green: 0.27, blue: 0.60)
        case .magenta: return Color(red: 0.78, green: 0.24, blue: 0.48)
        case .sunset:  return Color(red: 0.92, green: 0.36, blue: 0.30)
        case .lagoon:  return Color(red: 0.16, green: 0.46, blue: 0.74)
        case .meadow:  return Color(red: 0.22, green: 0.56, blue: 0.34)
        case .candy:   return Color(red: 0.86, green: 0.30, blue: 0.56)
        case .mango:   return Color(red: 0.94, green: 0.55, blue: 0.18)
        case .grape:   return Color(red: 0.46, green: 0.28, blue: 0.66)
        case .aurora:  return Color(red: 0.16, green: 0.56, blue: 0.56)
        case .ember:   return Color(red: 0.80, green: 0.22, blue: 0.24)
        }
    }

    /// The gradient for gradient tints; `nil` for flat-colour tints.
    var gradient: LinearGradient? {
        guard let pair = gradientColors else { return nil }
        return LinearGradient(colors: [pair.0, pair.1],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }

    /// A `ShapeStyle` for prominent fills: the gradient when present, else the
    /// flat colour. Wrapped in `AnyShapeStyle` so call sites stay uniform.
    var style: AnyShapeStyle {
        if let gradient { return AnyShapeStyle(gradient) }
        return AnyShapeStyle(color)
    }

    /// Start/end colours backing each gradient tint.
    private var gradientColors: (Color, Color)? {
        switch self {
        case .sunset:  return (Color(red: 0.97, green: 0.55, blue: 0.20),
                               Color(red: 0.86, green: 0.18, blue: 0.40))
        case .lagoon:  return (Color(red: 0.20, green: 0.58, blue: 0.86),
                               Color(red: 0.10, green: 0.32, blue: 0.62))
        case .meadow:  return (Color(red: 0.42, green: 0.72, blue: 0.34),
                               Color(red: 0.10, green: 0.44, blue: 0.40))
        case .candy:   return (Color(red: 0.96, green: 0.45, blue: 0.66),
                               Color(red: 0.56, green: 0.24, blue: 0.72))
        case .mango:   return (Color(red: 0.98, green: 0.74, blue: 0.20),
                               Color(red: 0.90, green: 0.36, blue: 0.18))
        case .grape:   return (Color(red: 0.56, green: 0.36, blue: 0.80),
                               Color(red: 0.26, green: 0.20, blue: 0.56))
        case .aurora:  return (Color(red: 0.22, green: 0.70, blue: 0.62),
                               Color(red: 0.14, green: 0.40, blue: 0.66))
        case .ember:   return (Color(red: 0.92, green: 0.40, blue: 0.22),
                               Color(red: 0.66, green: 0.12, blue: 0.22))
        default:       return nil
        }
    }

    var displayName: String {
        switch self {
        case .red:     return "Record Red"
        case .orange:  return "Sunburst"
        case .amber:   return "Amber"
        case .green:   return "Forest"
        case .teal:    return "Teal"
        case .blue:    return "Ocean"
        case .plum:    return "Plum"
        case .magenta: return "Magenta"
        case .sunset:  return "Sunset"
        case .lagoon:  return "Lagoon"
        case .meadow:  return "Meadow"
        case .candy:   return "Candy"
        case .mango:   return "Mango"
        case .grape:   return "Grape"
        case .aurora:  return "Aurora"
        case .ember:   return "Ember"
        }
    }
}

enum CassetteFont {
    /// Used for the "label paper" titles on cassette tiles and the player.
    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Used for time codes, counters and other digital readouts.
    static func counter(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Used for chunky transport button labels.
    static func transport(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

/// Wraps a view in the global app background suitable for the cassette aesthetic.
struct CassetteBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if scheme == .dark {
                        CassettePalette.darkBackgroundGradient
                    } else {
                        CassettePalette.backgroundGradient
                    }
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func cassetteBackground() -> some View { modifier(CassetteBackground()) }
}
