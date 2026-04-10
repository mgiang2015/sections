import SwiftUI

/// Presented as a sheet from SectionFormView when the user taps "Mark Live".
/// Plays the full audio file and lets the user tap to set start and end timestamps.
struct LiveMarkingView: View {

    @ObservedObject var playbackViewModel: PlaybackViewModel
    let audioFile: AudioFile

    /// Called when the user confirms their marked timestamps.
    var onConfirm: (TimeInterval, TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var markedStart: TimeInterval? = nil
    @State private var markedEnd: TimeInterval? = nil
    @State private var markingStep: MarkingStep = .start
    @State private var showConfirmError: String? = nil

    enum MarkingStep { case start, end, done }

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
            .navigationTitle("Mark Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        playbackViewModel.stopAndReset()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        confirmMarks()
                    }
                    .disabled(markedStart == nil || markedEnd == nil)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                playbackViewModel.playFromBeginning(audioFile: audioFile)
            }
            .onDisappear {
                // Safety net — stop audio if sheet is dismissed without tapping Cancel
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
                Text(stepTitle)
                    .font(.headline)
                Text(stepSubtitle)
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
                time: markedStart,
                color: .green,
                isActive: markingStep == .start
            )

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.title3)

            timestampCard(
                label: "End",
                time: markedEnd,
                color: .blue,
                isActive: markingStep == .end
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
            // Tappable progress bar for scrubbing
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * playbackViewModel.progress, height: 6)

                    // Start marker
                    if let start = markedStart, playbackViewModel.duration > 0 {
                        markerLine(at: start / playbackViewModel.duration, in: geo.size.width, color: .green)
                    }

                    // End marker
                    if let end = markedEnd, playbackViewModel.duration > 0 {
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
        Button {
            markCurrentTime()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: markingStep == .start ? "flag.fill" : "flag.checkered")
                Text(markingStep == .start ? "Mark Start" : markingStep == .end ? "Mark End" : "Re-mark Start")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(markButtonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)

        // Inline error (e.g. end before start)
        .overlay(alignment: .bottom) {
            if let err = showConfirmError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .offset(y: 20)
            }
        }
        .padding(.bottom, showConfirmError != nil ? 12 : 0)
    }

    private var transportRow: some View {
        HStack(spacing: 40) {
            // Skip back 5s
            Button {
                playbackViewModel.seek(to: playbackViewModel.currentTime - 5)
            } label: {
                Image(systemName: "gobackward.5")
                    .font(.title2)
            }

            // Play / Pause
            Button {
                playbackViewModel.togglePlayPause()
            } label: {
                Image(systemName: playbackViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)
            }

            // Skip forward 5s
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
        switch markingStep {
        case .start: return "flag.fill"
        case .end:   return "flag.checkered"
        case .done:  return "checkmark.circle.fill"
        }
    }

    private var stepColor: Color {
        switch markingStep {
        case .start: return .green
        case .end:   return .blue
        case .done:  return .purple
        }
    }

    private var stepTitle: String {
        switch markingStep {
        case .start: return "Step 1 — Mark Start"
        case .end:   return "Step 2 — Mark End"
        case .done:  return "Both timestamps marked"
        }
    }

    private var stepSubtitle: String {
        switch markingStep {
        case .start: return "Play the audio and tap Mark Start at the right moment"
        case .end:   return "Continue playing and tap Mark End when the section finishes"
        case .done:  return "Tap Use to apply, or tap Mark Start again to redo"
        }
    }

    private var markButtonColor: Color {
        switch markingStep {
        case .start: return .green
        case .end:   return .blue
        case .done:  return .green  // re-mark start
        }
    }

    // MARK: - Logic

    private func markCurrentTime() {
        showConfirmError = nil
        let now = playbackViewModel.currentTime

        switch markingStep {
        case .start:
            markedStart = now
            markedEnd = nil      // clear end whenever start is re-marked
            markingStep = .end

        case .end:
            guard let start = markedStart, now > start else {
                showConfirmError = "End must be after start. Keep playing and try again."
                return
            }
            markedEnd = now
            markingStep = .done

        case .done:
            // Allow redo — reset back to start
            markedStart = nil
            markedEnd = nil
            markingStep = .start
        }
    }

    private func confirmMarks() {
        guard let start = markedStart, let end = markedEnd else { return }
        guard end > start else {
            showConfirmError = "End must be after start."
            return
        }
        playbackViewModel.stopAndReset()
        onConfirm(start, end)
        dismiss()
    }
}
