import SwiftUI

/// Presented as a sheet from SectionFormView when the user taps "Mark with Audio".
/// Plays the full audio file and lets the user tap to set start and end timestamps.
struct LiveMarkingView: View {

    @ObservedObject var playbackViewModel: PlaybackViewModel
    let audioFile: AudioFile

    /// Called when the user confirms their marked timestamps.
    var onConfirm: (TimeInterval, TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var markingVM = LiveMarkingViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                instructionBanner
                    .padding(.horizontal)
                    .padding(.top, 16)

                Spacer()

                markedTimestampsDisplay
                    .padding(.horizontal)

                Spacer()

                progressSection
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                markButton
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                transportRow
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Mark with Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        playbackViewModel.stopAndReset()
                        markingVM.reset()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        confirmMarks()
                    }
                    .disabled(!markingVM.canConfirm)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                playbackViewModel.playFromBeginning(audioFile: audioFile)
            }
            .onDisappear {
                if playbackViewModel.isPlaying {
                    playbackViewModel.stopAndReset()
                }
            }
        }
    }

    // MARK: - Subviews

    private var instructionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: stepIcon)
                .font(.title2)
                .foregroundStyle(stepColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(markingVM.stepTitle)
                    .font(.headline)
                Text(markingVM.stepSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(stepColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var markedTimestampsDisplay: some View {
        HStack(spacing: 20) {
            timestampCard(
                label: "Start",
                time: markingVM.markedStart,
                color: .green,
                isActive: markingVM.step == .start
            )

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.title3)

            timestampCard(
                label: "End",
                time: markingVM.markedEnd,
                color: .blue,
                isActive: markingVM.step == .end
            )
        }
    }

    private func timestampCard(label: String, time: TimeInterval?, color: Color, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(time.map { TimeFormatter.format($0) } ?? "--:--")
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(time != nil ? color : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isActive ? color.opacity(0.08) : Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? color : Color.clear, lineWidth: 2)
        )
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * playbackViewModel.progress, height: 6)

                    if let start = markingVM.markedStart, playbackViewModel.duration > 0 {
                        markerLine(at: start / playbackViewModel.duration, in: geo.size.width, color: .green)
                    }

                    if let end = markingVM.markedEnd, playbackViewModel.duration > 0 {
                        markerLine(at: end / playbackViewModel.duration, in: geo.size.width, color: .blue)
                    }
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / geo.size.width))
                        playbackViewModel.seek(to: ratio * playbackViewModel.duration)
                    }
                )
            }
            .frame(height: 24)

            HStack {
                Text(TimeFormatter.format(playbackViewModel.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormatter.format(playbackViewModel.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func markerLine(at ratio: Double, in width: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 20)
            .offset(x: width * ratio - 1)
    }

    private var markButton: some View {
        VStack(spacing: 8) {
            Button {
                markingVM.mark(at: playbackViewModel.currentTime)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: markingVM.step == .start ? "flag.fill" : "flag.checkered")
                    Text(markingVM.markButtonLabel)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(markButtonColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if let err = markingVM.markError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var transportRow: some View {
        HStack(spacing: 40) {
            Button {
                playbackViewModel.seek(to: playbackViewModel.currentTime - 5)
            } label: {
                Image(systemName: "gobackward.5")
                    .font(.title2)
            }

            Button {
                playbackViewModel.togglePlayPause()
            } label: {
                Image(systemName: playbackViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)
            }

            Button {
                playbackViewModel.seek(to: playbackViewModel.currentTime + 5)
            } label: {
                Image(systemName: "goforward.5")
                    .font(.title2)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Step display helpers

    private var stepIcon: String {
        switch markingVM.step {
        case .start: return "flag.fill"
        case .end:   return "flag.checkered"
        case .done:  return "checkmark.circle.fill"
        }
    }

    private var stepColor: Color {
        switch markingVM.step {
        case .start: return .green
        case .end:   return .blue
        case .done:  return .purple
        }
    }

    private var markButtonColor: Color {
        switch markingVM.step {
        case .start: return .green
        case .end:   return .blue
        case .done:  return .green
        }
    }

    // MARK: - Logic

    private func confirmMarks() {
        guard let (start, end) = markingVM.confirm() else { return }
        playbackViewModel.stopAndReset()
        onConfirm(start, end)
        dismiss()
    }
}
