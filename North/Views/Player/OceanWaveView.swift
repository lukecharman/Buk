import SwiftUI

/// A mesmerising animated ocean-wave visualisation clipped to a circle.
///
/// Three layered sine waves — back, mid, and front — advance at different
/// speeds, creating a convincing breaking-surf effect. The wave `energy`
/// smoothly rises when `isPlaying` is `true` and subsides to a gentle calm
/// when playback is paused.
struct OceanWaveView: View {
    let isPlaying: Bool
    let size: CGFloat

    @State private var startDate = Date()
    @State private var energy: Double

    init(isPlaying: Bool, size: CGFloat = 160) {
        self.isPlaying = isPlaying
        self.size = size
        _energy = State(initialValue: isPlaying ? 1.0 : 0.12)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, sz in
                drawScene(ctx: ctx, size: sz, t: t)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(
            color: Color(red: 0.04, green: 0.18, blue: 0.32).opacity(0.55),
            radius: 18, y: 6
        )
        .onAppear { startDate = Date() }
        .onChange(of: isPlaying) { _, playing in
            withAnimation(.easeInOut(duration: 1.4)) {
                energy = playing ? 1.0 : 0.12
            }
        }
    }

    // MARK: - Scene

    private func drawScene(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width
        let h = size.height

        // ── Sky ──────────────────────────────────────────────────────────────
        let skyH = h * 0.44
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: skyH)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.55, green: 0.83, blue: 0.96), location: 0),
                    .init(color: Color(red: 0.22, green: 0.62, blue: 0.86), location: 0.65),
                    .init(color: Color(red: 0.16, green: 0.50, blue: 0.78), location: 1),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: skyH)
            )
        )

        // ── Horizon warm glow ─────────────────────────────────────────────────
        let glowH = h * 0.16
        ctx.fill(
            Path(CGRect(x: 0, y: skyH - glowH * 0.5,
                        width: w, height: glowH)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.95, green: 0.80, blue: 0.55).opacity(0),
                    Color(red: 0.95, green: 0.80, blue: 0.55).opacity(0.30 * energy),
                    Color(red: 0.95, green: 0.80, blue: 0.55).opacity(0),
                ]),
                startPoint: CGPoint(x: 0, y: skyH - glowH * 0.5),
                endPoint: CGPoint(x: 0, y: skyH + glowH * 0.5)
            )
        )

        // ── Deep water ────────────────────────────────────────────────────────
        ctx.fill(
            Path(CGRect(x: 0, y: skyH, width: w, height: h - skyH + 10)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.10, green: 0.44, blue: 0.66), location: 0),
                    .init(color: Color(red: 0.06, green: 0.28, blue: 0.50), location: 0.35),
                    .init(color: Color(red: 0.03, green: 0.14, blue: 0.30), location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: skyH),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Gentle breath modulation adds organic amplitude variation.
        let breath = 0.88 + 0.12 * sin(t * 0.65)
        let e = energy * breath
        // Water level rises slightly when playing.
        let waterLevel = h * (0.46 + 0.05 * (1.0 - energy))

        // ── Wave 1 – back, slow ───────────────────────────────────────────────
        let amp1  = e * h * 0.085
        let ph1   = t * 0.52
        ctx.fill(
            waveFill(size: size, phase: ph1, amplitude: amp1,
                     frequency: 1.45, waterLevel: waterLevel + h * 0.04),
            with: .color(Color(red: 0.08, green: 0.38, blue: 0.64).opacity(0.62))
        )

        // ── Wave 2 – mid ──────────────────────────────────────────────────────
        let amp2  = e * h * 0.105
        let ph2   = t * 0.82 + 1.5
        ctx.fill(
            waveFill(size: size, phase: ph2, amplitude: amp2,
                     frequency: 1.10, waterLevel: waterLevel + h * 0.01),
            with: .color(Color(red: 0.14, green: 0.54, blue: 0.74).opacity(0.70))
        )

        // ── Wave 3 – front, fast ──────────────────────────────────────────────
        let amp3  = e * h * 0.125
        let ph3   = t * 1.32 + 0.6
        ctx.fill(
            waveFill(size: size, phase: ph3, amplitude: amp3,
                     frequency: 0.95, waterLevel: waterLevel - h * 0.02),
            with: .color(Color(red: 0.26, green: 0.72, blue: 0.90).opacity(0.78))
        )

        // ── Foam crest on wave 3 ──────────────────────────────────────────────
        ctx.stroke(
            waveLine(size: size, phase: ph3, amplitude: amp3 * 1.04,
                     frequency: 0.95, waterLevel: waterLevel - h * 0.02),
            with: .color(.white.opacity(0.55 * e)),
            lineWidth: 1.8
        )

        // ── Capillary ripples ─────────────────────────────────────────────────
        let ripAmp = e * h * 0.022
        ctx.stroke(
            waveLine(size: size, phase: t * 2.9 + 2.2, amplitude: ripAmp,
                     frequency: 2.9, waterLevel: waterLevel - h * 0.065),
            with: .color(.white.opacity(0.18 * e)),
            lineWidth: 0.7
        )

        // ── Foam particles ────────────────────────────────────────────────────
        drawFoam(ctx: ctx, size: size,
                 phase: ph3, amplitude: amp3, frequency: 0.95,
                 waterLevel: waterLevel - h * 0.02, t: t, energy: e)

        // ── Sun shimmer on water ──────────────────────────────────────────────
        drawShimmer(ctx: ctx, size: size, waterLevel: waterLevel, t: t, energy: e)
    }

    // MARK: - Wave geometry

    /// Vertical position of the wave surface at horizontal position `x`.
    private func waveY(x: Double, w: Double, phase: Double,
                       amplitude: Double, frequency: Double,
                       waterLevel: Double) -> Double {
        let norm = (x / w) * 2 * .pi * frequency + phase
        // Superposition of harmonics produces a realistic breaking-wave profile:
        // the second harmonic sharpens the peaks; the third adds mild asymmetry.
        let y = sin(norm)
             + 0.18 * sin(2 * norm + 0.40)
             - 0.07 * cos(3 * norm + 0.20)
        return waterLevel - amplitude * y
    }

    /// Closed path for a wave layer (surface + bottom edge).
    private func waveFill(size: CGSize, phase: Double, amplitude: Double,
                          frequency: Double, waterLevel: Double) -> Path {
        var path = Path()
        let w = size.width, h = size.height
        let steps = 100
        for i in 0...steps {
            let x = Double(i) / Double(steps) * w
            let y = waveY(x: x, w: w, phase: phase, amplitude: amplitude,
                          frequency: frequency, waterLevel: waterLevel)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.addLine(to: CGPoint(x: w, y: h + 10))
        path.addLine(to: CGPoint(x: 0, y: h + 10))
        path.closeSubpath()
        return path
    }

    /// Open path along the wave surface only (used for stroke effects).
    private func waveLine(size: CGSize, phase: Double, amplitude: Double,
                          frequency: Double, waterLevel: Double) -> Path {
        var path = Path()
        let w = size.width
        let steps = 100
        for i in 0...steps {
            let x = Double(i) / Double(steps) * w
            let y = waveY(x: x, w: w, phase: phase, amplitude: amplitude,
                          frequency: frequency, waterLevel: waterLevel)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    // MARK: - Decorative effects

    /// Small foam circles that bob along the front-wave crest.
    private func drawFoam(ctx: GraphicsContext, size: CGSize,
                          phase: Double, amplitude: Double, frequency: Double,
                          waterLevel: Double, t: Double, energy: Double) {
        let w = size.width
        let count = 10
        for i in 0..<count {
            let xFrac = Double(i) / Double(count - 1)
            let x     = xFrac * w
            let y     = waveY(x: x, w: w, phase: phase,
                              amplitude: amplitude * 0.91,
                              frequency: frequency, waterLevel: waterLevel)
            let pulse  = (sin(t * 2.8 + Double(i) * 0.95) + 1) * 0.5
            let r      = (1.8 + 2.0 * pulse) * energy
            guard r > 0.3 else { continue }
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.42 * energy * pulse))
            )
        }
    }

    /// Horizontal shimmer streaks that drift across the water surface, evoking
    /// sunlight glinting on the sea.
    private func drawShimmer(ctx: GraphicsContext, size: CGSize,
                             waterLevel: Double, t: Double, energy: Double) {
        let w = size.width
        for i in 0..<3 {
            let frac  = ((t * 0.14 + Double(i) * 0.33)
                          .truncatingRemainder(dividingBy: 1.0))
            let xBase = frac * w
            let yBase = waterLevel + Double(i) * size.height * 0.065
            let sW    = w * 0.20
            let sH    = size.height * 0.012
            let rect  = CGRect(x: xBase - sW * 0.5, y: yBase - sH * 0.5,
                               width: sW, height: sH)
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [
                        .white.opacity(0),
                        .white.opacity(0.20 * energy),
                        .white.opacity(0),
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                )
            )
        }
    }
}
