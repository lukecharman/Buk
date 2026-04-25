import SwiftUI

/// A skeuomorphic cassette tape rendered entirely in SwiftUI.
///
/// - Body uses charcoal plastic with subtle highlights.
/// - Two reels rotate while playing; the *amount of tape* on each reel reflects the
///   current `progress` (0 = all tape on the right reel, 1 = all on the left), giving
///   the satisfying physical feel of a tape playing through.
/// - Optional cover artwork is shown on the cassette label so the user recognises
///   the audiobook at a glance.
struct CassetteDeckView: View {
    let title: String
    let subtitle: String?
    let progress: Double
    let isPlaying: Bool
    let cover: Image?

    @State private var rotation: Angle = .zero
    @State private var rotationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width * 0.62 // cassette aspect
            ZStack {
                shell(width: width, height: height)
                label(width: width, height: height)
                reels(width: width, height: height)
                screws(width: width, height: height)
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1.0 / 0.62, contentMode: .fit)
        .onAppear { syncSpinning() }
        .onChange(of: isPlaying) { _, _ in syncSpinning() }
        .onDisappear {
            rotationTask?.cancel()
            rotationTask = nil
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title) cassette"))
        .accessibilityValue(Text(String(format: "%.0f percent played", progress * 100)))
    }

    // MARK: - Components

    private func shell(width: CGFloat, height: CGFloat) -> some View {
        let r = width * 0.06
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(colors: [CassettePalette.plastic, CassettePalette.charcoal],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(
                // glossy highlight
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top, endPoint: .center)
                    )
                    .blendMode(.plusLighter)
                    .padding(2)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
    }

    private func label(width: CGFloat, height: CGFloat) -> some View {
        let labelWidth = width * 0.78
        let labelHeight = height * 0.36
        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(CassettePalette.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(CassettePalette.labelInk.opacity(0.15), lineWidth: 0.5)
                )
                .overlay(
                    HStack(spacing: 8) {
                        if let cover {
                            cover
                                .resizable()
                                .scaledToFill()
                                .frame(width: labelHeight - 12, height: labelHeight - 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(CassetteFont.label(min(labelHeight * 0.32, 18)))
                                .foregroundStyle(CassettePalette.labelInk)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                            if let subtitle {
                                Text(subtitle)
                                    .font(CassetteFont.label(min(labelHeight * 0.22, 12), weight: .regular))
                                    .foregroundStyle(CassettePalette.labelInk.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                )
                .frame(width: labelWidth, height: labelHeight)
                .position(x: width / 2, y: height * 0.27)
            // Side A indicator
            Text("SIDE A")
                .font(CassetteFont.counter(8, weight: .bold))
                .foregroundStyle(CassettePalette.labelInk.opacity(0.6))
                .position(x: width / 2, y: height * 0.47)
        }
    }

    private func reels(width: CGFloat, height: CGFloat) -> some View {
        let reelDiameter = height * 0.34
        let centerY = height * 0.72
        let leftX = width * 0.30
        let rightX = width * 0.70
        // Left reel takes on more tape as progress advances.
        let leftFill  = 0.35 + 0.50 * progress
        let rightFill = 0.85 - 0.50 * progress

        return ZStack {
            // Tape window between reels
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(CassettePalette.tape)
                .frame(width: rightX - leftX, height: height * 0.05)
                .position(x: width / 2, y: centerY)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(.black.opacity(0.5), lineWidth: 0.5)
                        .frame(width: rightX - leftX, height: height * 0.05)
                        .position(x: width / 2, y: centerY)
                )

            reel(diameter: reelDiameter, fill: leftFill)
                .rotationEffect(rotation)
                .position(x: leftX, y: centerY)
            reel(diameter: reelDiameter, fill: rightFill)
                .rotationEffect(rotation)
                .position(x: rightX, y: centerY)
        }
    }

    private func reel(diameter: CGFloat, fill: Double) -> some View {
        let outer = diameter
        let hub   = diameter * 0.35
        let tapeRadius = hub + (outer / 2 - hub) * fill
        return ZStack {
            // Tape donut
            Circle()
                .fill(CassettePalette.tapeHL)
                .frame(width: tapeRadius * 2, height: tapeRadius * 2)
            Circle()
                .fill(CassettePalette.tape)
                .frame(width: tapeRadius * 2 - 4, height: tapeRadius * 2 - 4)
            // Hub well behind the spokes
            Circle()
                .fill(CassettePalette.charcoal)
                .frame(width: hub * 1.2, height: hub * 1.2)
            // Hub
            Circle()
                .fill(CassettePalette.aluminium)
                .frame(width: hub, height: hub)
                .overlay(
                    ZStack {
                        ForEach(0..<6) { i in
                            Capsule()
                                .fill(CassettePalette.charcoal)
                                .frame(width: 2, height: hub * 0.7)
                                .rotationEffect(.degrees(Double(i) * 60))
                        }
                        Circle()
                            .fill(CassettePalette.charcoal)
                            .frame(width: hub * 0.18, height: hub * 0.18)
                    }
                )
        }
        .compositingGroup()
    }

    private func screws(width: CGFloat, height: CGFloat) -> some View {
        let positions: [CGPoint] = [
            .init(x: width * 0.05, y: height * 0.08),
            .init(x: width * 0.95, y: height * 0.08),
            .init(x: width * 0.05, y: height * 0.92),
            .init(x: width * 0.95, y: height * 0.92),
            .init(x: width * 0.5,  y: height * 0.92)
        ]
        return ZStack {
            ForEach(0..<positions.count, id: \.self) { i in
                Circle()
                    .fill(CassettePalette.aluminium)
                    .overlay(
                        Rectangle()
                            .fill(CassettePalette.charcoal)
                            .frame(width: 6, height: 1.2)
                    )
                    .frame(width: 8, height: 8)
                    .position(positions[i])
            }
        }
    }

    // MARK: - Animation

    private func syncSpinning() {
        rotationTask?.cancel()
        guard isPlaying else { return }
        rotationTask = Task { @MainActor in
            while !Task.isCancelled, isPlaying {
                withAnimation(.linear(duration: 1.0)) {
                    rotation += .degrees(45)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
