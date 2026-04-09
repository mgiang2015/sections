import SwiftUI

/// Inline playback controls shown at the bottom of SectionsListView when a section is active.
struct PlaybackControlsView: View {

    @ObservedObject var viewModel: PlaybackViewModel

    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        VStack(spacing: 12) {
            // Section name + mode toggle
            if let section = viewModel.activeSection {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.name)
                            .font(.headline)
                        Text("\(section.startTimeFormatted) → \(section.endTimeFormatted)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Playback mode toggle
                    Button {
                        viewModel.togglePlaybackMode()
                    } label: {
                        Image(systemName: viewModel.currentPlaybackMode == .loop ? "repeat" : "play")
                            .foregroundStyle(viewModel.currentPlaybackMode == .loop ? .blue : .secondary)
                    }
                    .accessibilityLabel(viewModel.currentPlaybackMode == .loop ? "Loop on" : "Play once")
                }
            }

            // Progress bar
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(.blue)

            // Transport controls
            HStack(spacing: 32) {
                // Replay
                Button {
                    viewModel.replay()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }
                .accessibilityLabel("Replay section")

                // Play / Pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                // Placeholder for future control symmetry
                Spacer().frame(width: 28)
            }
            .frame(maxWidth: .infinity)

            // Speed picker
            Picker("Speed", selection: $viewModel.playbackRate) {
                ForEach(speedOptions, id: \.self) { speed in
                    Text(formatSpeed(speed)).tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func formatSpeed(_ speed: Float) -> String {
        speed == 1.0 ? "1×" : String(format: speed.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f×" : "%.2g×", speed)
    }
}
