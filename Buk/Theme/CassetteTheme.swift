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
