import SwiftUI
import Combine
import AVFoundation

struct StoryView: View {
    @EnvironmentObject private var viewModel: GameViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(viewModel.story.chapters) { chapter in
                    StoryChapterCard(chapter: chapter)
                        .environmentObject(viewModel)
                        .transition(.opacity)
                }

                if viewModel.isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.accent)
                        Text("Weaving the next chapter...")
                            .font(.callout)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                }
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
    }
}

struct StoryView_Previews: PreviewProvider {
    static var previews: some View {
        StoryView().environmentObject(GameViewModel())
            .background(Theme.background)
    }
}

private struct StoryChapterCard: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let chapter: StoryChapter

    private var isCurrentNode: Bool {
        viewModel.story.currentChapter?.id == chapter.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let sel = chapter.selectedOptionId,
               let label = chapter.choices.first(where: { $0.id == sel })?.label {
                Text(label)
                    .font(Theme.monoCaption())
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Text(chapter.narrative)
                .font(Theme.bodyFont())
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Theme.divider.opacity(0.5))

            HStack {
                if chapter.regenerationCount > 1 {
                    Text("Attempt \(chapter.regenerationCount)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text(isCurrentNode ? "Current chapter" : "Saved chapter")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.regenerate(chapter: chapter)
                    }
                } label: {
                    Label("Regenerate from here", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.isRefreshingChoices)
            }

            if viewModel.provider == .groq {
                NarrationControls(chapter: chapter)
                    .environmentObject(viewModel)
            }
        }
        .cardBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrentNode ? Theme.accent.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
    }
}

private struct NarrationControls: View {
    @EnvironmentObject private var viewModel: GameViewModel
    let chapter: StoryChapter

    @StateObject private var playback = NarrationPlaybackController()

    var body: some View {
        let state = viewModel.narrationState(for: chapter.id)

        VStack(alignment: .leading, spacing: 10) {
            if state.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.accent)
                    Text("Generating narration…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else if let audioURL = state.audioURL {
                Button {
                    playback.toggle(rate: state.playbackRate)
                } label: {
                    Label(playback.isPlaying ? "Pause narration" : "Play narration",
                          systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))

                VStack(alignment: .leading, spacing: 6) {
                    Label("Speed", systemImage: "gauge.medium")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Slider(
                        value: Binding(
                            get: { Double(state.playbackRate) },
                            set: { newValue in
                                viewModel.setNarrationRate(for: chapter.id, rate: Float(newValue))
                            }
                        ),
                        in: 0.75...1.5,
                        step: 0.05
                    )
                    .tint(Theme.accent)
                    Text(String(format: "%.2fx", state.playbackRate))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)
            } else {
                Button {
                    viewModel.generateNarration(for: chapter)
                } label: {
                    Label("Generate narration", systemImage: "waveform")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))
                .disabled(viewModel.isGenerating)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surface.opacity(0.75))
        )
        .onAppear {
            let initialState = viewModel.narrationState(for: chapter.id)
            if let audioURL = initialState.audioURL {
                playback.load(url: audioURL)
                playback.updateRate(initialState.playbackRate)
            }
        }
        .onChange(of: state.audioURL) { url in
            guard let url else {
                playback.stop()
                return
            }
            playback.load(url: url)
            playback.updateRate(viewModel.narrationState(for: chapter.id).playbackRate)
        }
        .onChange(of: state.playbackRate) { rate in
            playback.updateRate(rate)
        }
        .onDisappear {
            playback.stop()
        }
    }
}

@MainActor
private final class NarrationPlaybackController: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentRate: Float = 1.0

    private var player: AVAudioPlayer?

    func load(url: URL) {
        stop()
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.enableRate = true
            audioPlayer.prepareToPlay()
            audioPlayer.delegate = self
            player = audioPlayer
        } catch {
            player = nil
        }
    }

    func toggle(rate: Float) {
        if isPlaying {
            pause()
        } else {
            play(rate: rate)
        }
    }

    func play(rate: Float) {
        guard let player else { return }
        player.enableRate = true
        player.rate = rate
        player.currentTime = 0
        player.play()
        isPlaying = true
        currentRate = rate
    }

    func pause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
        }
        isPlaying = false
    }

    func stop() {
        if let player, player.isPlaying {
            player.stop()
        }
        isPlaying = false
        player = nil
    }

    func updateRate(_ rate: Float) {
        currentRate = rate
        guard let player, player.isPlaying else { return }
        player.rate = rate
    }
}

extension NarrationPlaybackController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
