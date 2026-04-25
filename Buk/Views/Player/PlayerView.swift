import SwiftUI

struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSleepTimerSheet = false
    @State private var showChaptersSheet = false

    init(book: Audiobook, library: LibraryViewModel) {
        _library = ObservedObject(wrappedValue: library)
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, library: library))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CassetteDeckView(
                    title: viewModel.book.title,
                    subtitle: viewModel.book.author,
                    progress: viewModel.bookFraction,
                    isPlaying: viewModel.isPlaying,
                    cover: viewModel.book.artworkImage(in: LibraryPaths.artworkFolder)
                )
                .padding(.horizontal)

                titleBlock
                ScrubberView(viewModel: viewModel)
                TransportControlsView(viewModel: viewModel)
                SpeedDialView(viewModel: viewModel)
                accessoryRow
                    .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .cassetteBackground()
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.tearDown() }
        .alert("Playback error",
               isPresented: Binding(get: { viewModel.playbackError != nil },
                                    set: { if !$0 { viewModel.playbackError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.playbackError ?? "") }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showChaptersSheet) {
            NavigationStack {
                ChapterListView(book: viewModel.book,
                                progress: library.progress(for: viewModel.book),
                                onSelect: { index in
                                    viewModel.jumpToChapter(at: index)
                                    showChaptersSheet = false
                                })
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showChaptersSheet = true } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Chapters")
            }
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(viewModel.currentChapter?.title ?? viewModel.book.title)
                .font(CassetteFont.label(20))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
            if let author = viewModel.book.author {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var accessoryRow: some View {
        HStack(spacing: 12) {
            Button {
                showSleepTimerSheet = true
            } label: {
                Label(sleepTimerLabel, systemImage: "moon.zzz.fill")
                    .padding(.horizontal, 14).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 16)

            Button {
                showChaptersSheet = true
            } label: {
                Label("Chapters", systemImage: "list.bullet")
                    .padding(.horizontal, 14).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 16)
        }
    }

    private var sleepTimerLabel: String {
        if let remaining = viewModel.sleepTimerRemaining {
            let mins = max(0, Int(remaining.rounded(.up))) / 60
            let secs = max(0, Int(remaining.rounded(.up))) % 60
            return String(format: "Sleep %d:%02d", mins, secs)
        }
        return "Sleep timer"
    }
}

private struct SleepTimerSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(SettingsStore.allowedSleepTimers, id: \.self) { minutes in
                    Button {
                        viewModel.setSleepTimer(minutes: minutes)
                        dismiss()
                    } label: {
                        HStack {
                            Text(minutes == 0 ? "Off" : "\(minutes) minutes")
                            Spacer()
                            if minutes == 0 && viewModel.sleepTimerRemaining == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
