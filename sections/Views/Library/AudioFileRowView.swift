import SwiftUI

/// A single row in the audio library list.
struct AudioFileRowView: View {

    let audioFile: AudioFile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(audioFile.filename)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 12) {
                Label("\(audioFile.sections.count) section\(audioFile.sections.count == 1 ? "" : "s")", systemImage: "scissors")
                Label(audioFile.dateAdded.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
