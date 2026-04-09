import SwiftUI

/// A single row representing an AudioSection in the sections list.
struct SectionRowView: View {

    let section: AudioSection
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Playing indicator
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(isPlaying ? .blue : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isPlaying)

            VStack(alignment: .leading, spacing: 4) {
                Text(section.name)
                    .font(.headline)
                    .foregroundStyle(isPlaying ? .blue : .primary)

                HStack(spacing: 8) {
                    Text("\(section.startTimeFormatted) → \(section.endTimeFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(section.playbackMode.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(section.lastPlayed.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
