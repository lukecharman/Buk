import SwiftUI

/// A skeuomorphic cassette tape rendered entirely in SwiftUI.
///
/// - Body uses charcoal plastic with subtle highlights and a recessed window
///   around the reels.
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
    /// Hide the title/subtitle/"A" text printed on the cassette label so only
    /// the cover image shows — used for the Library grid where the surrounding
    /// UI already conveys identity.
    var showsLabelText: Bool = true

    @State private var rotation: Angle = .zero
    @State private var rotationTask: Task<Void, Never>?

    /// The cassette is laid out internally at this width so that text wraps and
    /// font sizes are computed once. The whole thing is then scaled to fill the
    /// container, which keeps the matched-geometry zoom buttery-smooth and
    /// prevents text reflowing at intermediate sizes.
    private let referenceWidth: CGFloat = 360

    var body: some View {
        let referenceHeight = referenceWidth * 0.62
        GeometryReader { proxy in
            let scale = max(0.01, proxy.size.width / referenceWidth)
            ZStack {
                shell(width: referenceWidth, height: referenceHeight)
                writeProtectTabs(width: referenceWidth, height: referenceHeight)
                label(width: referenceWidth, height: referenceHeight)
                window(width: referenceWidth, height: referenceHeight)
                reels(width: referenceWidth, height: referenceHeight)
                brandStrip(width: referenceWidth, height: referenceHeight)
                screws(width: referenceWidth, height: referenceHeight)
            }
            .frame(width: referenceWidth, height: referenceHeight)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width,
                   height: proxy.size.width * 0.62,
                   alignment: .topLeading)
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
        let r = width * 0.045
        return ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.22, blue: 0.24),
                            Color(red: 0.13, green: 0.13, blue: 0.14),
                            Color(red: 0.08, green: 0.08, blue: 0.09)
                        ],
                        startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    // top sheen
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.22), .clear],
                                startPoint: .top, endPoint: .center)
                        )
                        .blendMode(.plusLighter)
                        .padding(1)
                )
                .overlay(
                    // bottom rim shadow
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.35)],
                                startPoint: .center, endPoint: .bottom)
                        )
                        .blendMode(.multiply)
                        .padding(1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)
        }
    }

    private func writeProtectTabs(width: CGFloat, height: CGFloat) -> some View {
        let tabW = width * 0.04
        let tabH = height * 0.05
        return ZStack {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .frame(width: tabW, height: tabH)
                .position(x: width * 0.06, y: height * 0.04)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .frame(width: tabW, height: tabH)
                .position(x: width * 0.94, y: height * 0.04)
        }
    }

    private func label(width: CGFloat, height: CGFloat) -> some View {
        let labelWidth = width * 0.80
        let labelHeight = height * 0.40
        let r: CGFloat = 3
        return ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [CassettePalette.paper,
                                 CassettePalette.paper.opacity(0.92)],
                        startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    // colour bar at the top of the label
                    LinearGradient(
                        colors: [CassettePalette.recordRed.opacity(0.85),
                                 CassettePalette.recordRed.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing)
                    .frame(height: labelHeight * 0.16)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(CassettePalette.labelInk.opacity(0.18), lineWidth: 0.5)
                )
                .overlay(
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Spacer(minLength: labelHeight * 0.13)
                            if showsLabelText {
                                Text(title)
                                    .font(CassetteFont.label(labelHeight * 0.22))
                                    .foregroundStyle(CassettePalette.labelInk)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.55)
                                if let subtitle {
                                    Text(subtitle)
                                        .font(CassetteFont.label(labelHeight * 0.15, weight: .regular))
                                        .foregroundStyle(CassettePalette.labelInk.opacity(0.7))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                        if showsLabelText {
                            Text("A")
                                .font(CassetteFont.label(labelHeight * 0.42, weight: .black))
                                .foregroundStyle(CassettePalette.labelInk.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, labelHeight * 0.10)
                )
                .frame(width: labelWidth, height: labelHeight)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                .position(x: width / 2, y: height * 0.30)
        }
    }

    private func window(width: CGFloat, height: CGFloat) -> some View {
        // Recessed darker pane around the reels.
        let winW = width * 0.78
        let winH = height * 0.30
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.black.opacity(0.55))
            .frame(width: winW, height: winH)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.black.opacity(0.7), lineWidth: 0.8)
            )
            .overlay(
                // inner top shadow for recess
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(colors: [.black.opacity(0.5), .clear],
                                       startPoint: .top, endPoint: .center)
                    )
                    .blendMode(.multiply)
                    .padding(0.5)
            )
            .position(x: width / 2, y: height * 0.72)
    }

    private func reels(width: CGFloat, height: CGFloat) -> some View {
        let reelDiameter = height * 0.26
        let centerY = height * 0.72
        let leftX = width * 0.30
        let rightX = width * 0.70
        // Left reel takes on more tape as progress advances.
        let leftFill  = 0.30 + 0.55 * progress
        let rightFill = 0.85 - 0.55 * progress

        return ZStack {
            // Tape strip running between the reels
            tapeStrip(width: rightX - leftX + reelDiameter, height: height * 0.04)
                .position(x: width / 2, y: centerY + reelDiameter * 0.40)

            reel(diameter: reelDiameter, fill: leftFill)
                .rotationEffect(rotation)
                .position(x: leftX, y: centerY)
            reel(diameter: reelDiameter, fill: rightFill)
                .rotationEffect(rotation)
                .position(x: rightX, y: centerY)
        }
    }

    private func tapeStrip(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(CassettePalette.tape)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(
                    LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.25)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .blendMode(.plusLighter)
        }
        .frame(width: width, height: height)
    }

    private func reel(diameter: CGFloat, fill: Double) -> some View {
        let outer = diameter
        let hub   = diameter * 0.42
        let tapeRadius = hub + (outer / 2 - hub) * fill
        return ZStack {
            // Tape donut outer rim
            Circle()
                .fill(CassettePalette.tapeHL)
                .frame(width: tapeRadius * 2, height: tapeRadius * 2)
                .shadow(color: .black.opacity(0.5), radius: 1)
            // Tape body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [CassettePalette.tape,
                                 CassettePalette.tape.opacity(0.85)],
                        center: .center, startRadius: 0,
                        endRadius: tapeRadius)
                )
                .frame(width: tapeRadius * 2 - 3, height: tapeRadius * 2 - 3)
            // Inner well
            Circle()
                .fill(Color.black.opacity(0.65))
                .frame(width: hub * 1.15, height: hub * 1.15)
            // Hub spokes / wheel
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.85),
                                                CassettePalette.aluminium],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: hub, height: hub)
                // Six teeth windows around the hub
                ForEach(0..<6) { i in
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: hub * 0.10, height: hub * 0.34)
                        .offset(y: -hub * 0.30)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
                Circle()
                    .fill(CassettePalette.charcoal)
                    .frame(width: hub * 0.22, height: hub * 0.22)
            }
        }
        .compositingGroup()
    }

    private func brandStrip(width: CGFloat, height: CGFloat) -> some View {
        Text("BUK · CHROME · 90")
            .font(CassetteFont.counter(width * 0.030, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.55))
            .position(x: width / 2, y: height * 0.96)
    }

    private func screws(width: CGFloat, height: CGFloat) -> some View {
        let positions: [CGPoint] = [
            .init(x: width * 0.045, y: height * 0.92),
            .init(x: width * 0.955, y: height * 0.92),
            .init(x: width * 0.5,   y: height * 0.50)
        ]
        return ZStack {
            ForEach(0..<positions.count, id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [.white.opacity(0.95),
                                                    CassettePalette.aluminium,
                                                    Color.black.opacity(0.5)],
                                           center: .topLeading,
                                           startRadius: 0, endRadius: 7)
                        )
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 5, height: 1)
                        .rotationEffect(.degrees(Double(i) * 35))
                }
                .frame(width: 7, height: 7)
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
