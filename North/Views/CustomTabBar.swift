import SwiftUI

/// The app's four destinations. Declared at file scope so the custom tab bar and
/// the root container can share it.
enum NorthTab: Hashable {
    case library, discover, settings, player
}

/// A bespoke glass tab bar that mirrors the iOS 26 floating style but lets us
/// attach a play/pause toggle directly onto the Now Playing pill. The three main
/// destinations live in one capsule; the player pill sits separately to the
/// right, growing a play/pause button to its left while a book is loaded.
struct CustomTabBar: View {
    @Binding var selection: NorthTab
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        HStack(spacing: 10) {
            mainCapsule
            playerCapsule
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background {
            TabBarBackdrop()
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private var isPlaying: Bool { library.currentPlayer != nil }

    private var mainCapsule: some View {
        HStack(spacing: isPlaying ? 14 : 26) {
            tabButton(.library, systemImage: "books.vertical.fill", label: "Library")
            tabButton(.discover, systemImage: "sparkles", label: "Discover")
                .overlay(alignment: .topTrailing) {
                    if !library.activeDownloads.isEmpty {
                        Circle()
                            .fill(settings.accent)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                            .accessibilityLabel("Downloads in progress")
                    }
                }
            tabButton(.settings, systemImage: "gearshape.fill", label: "Settings")
        }
        .padding(.horizontal, isPlaying ? 16 : 20)
        .padding(.vertical, 12)
        .cassetteGlass(cornerRadius: 28)
    }

    private var playerCapsule: some View {
        HStack(spacing: 8) {
            if let player = library.currentPlayer {
                PlayPauseButton(player: player, accent: settings.accent)
            }
            tabButton(.player, systemImage: "waveform", label: "Player")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cassetteGlass(cornerRadius: 28)
    }

    private func tabButton(_ tab: NorthTab, systemImage: String, label: String) -> some View {
        Button {
            selection = tab
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selection == tab ? AnyShapeStyle(settings.accent) : AnyShapeStyle(.secondary))
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
    }
}

/// A full-width progressive blur-and-fade behind the floating pills, recreating
/// the system tab bar's scroll-edge effect so content softly blurs and fades as
/// it scrolls underneath.
struct TabBarBackdrop: View {
    private var fadeMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black.opacity(0.4), location: 0.5),
                .init(color: .black.opacity(0.92), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(fadeMask)
    }
}

/// Play/pause control hosted in the player pill. Observes the player so its
/// glyph flips immediately as playback toggles.
private struct PlayPauseButton: View {
    @ObservedObject var player: PlayerViewModel
    let accent: Color

    var body: some View {
        Button {
            player.togglePlay()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}
