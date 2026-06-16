import SwiftUI

/// View helpers for adopting the iOS 26 Liquid Glass system in a way that still
/// gracefully renders on simulators and earlier SDKs that don't expose
/// `.glassEffect`. We funnel all glass usage through these wrappers so the rest of
/// the codebase can opt into Liquid Glass with one short modifier.
extension View {
    /// Applies a Liquid Glass effect with a rounded-rectangle clip, falling back to
    /// `.ultraThinMaterial` on platforms or SDKs without `glassEffect`.
    @ViewBuilder
    func cassetteGlass(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(.regular.tint(tint ?? .clear),
                             in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
        }
        #else
        self
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        #endif
    }

    /// Applies a Liquid Glass effect with a circular clip — used for round transport
    /// buttons.
    @ViewBuilder
    func cassetteGlassCircle(tint: Color? = nil) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(.regular.tint(tint ?? .clear), in: Circle())
        } else {
            self
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        }
        #else
        self
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        #endif
    }
}
