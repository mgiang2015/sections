import SwiftUI
import SwiftData

/// Modal form for creating or editing an AudioSection.
/// Pass `existingSection: nil` to create a new one.
struct SectionFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let audioFile: AudioFile
    var existingSection: AudioSection?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var startTimeText: String = "0:00"
    @State private var endTimeText: String = "0:00"
    @State private var playbackMode: PlaybackMode = .loop
    @State private var validationError: String?

    private var isEditing: Bool { existingSection != nil }
    private var audioDuration: TimeInterval {
        // TODO: In Sprint 5, inject real duration from AVFoundation
        // Placeholder: 15 minutes max per BRD
        15 * 60
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Name") {
                    TextField("e.g. Chorus, Verse 1", text: $name)
                        .autocorrectionDisabled()
                }

                SwiftUI.Section("Timestamps") {
                    HStack {
                        Text("Start")
                            .frame(width: 50, alignment: .leading)
                        TextField("0:00", text: $startTimeText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("End")
                            .frame(width: 50, alignment: .leading)
                        TextField("0:00", text: $endTimeText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("Format: mm:ss  (e.g. 1:30 for 1 minute 30 seconds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SwiftUI.Section("Playback") {
                    Picker("Mode", selection: $playbackMode) {
                        ForEach(PlaybackMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let error = validationError {
                    SwiftUI.Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Section" : "New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let section = existingSection else { return }
        name = section.name
        startTimeText = TimeFormatter.format(section.startTime)
        endTimeText   = TimeFormatter.format(section.endTime)
        playbackMode  = section.playbackMode
    }

    private func save() {
        guard let (start, end) = validate() else { return }

        if let section = existingSection {
            // Edit existing
            section.name = name.trimmingCharacters(in: .whitespaces)
            section.startTime = start
            section.endTime = end
            section.playbackMode = playbackMode
        } else {
            // Create new
            let newSection = AudioSection(name: name.trimmingCharacters(in: .whitespaces),
                                     startTime: start,
                                     endTime: end,
                                     playbackMode: playbackMode)
            newSection.audioFile = audioFile
            modelContext.insert(newSection)
        }

        dismiss()
    }

    /// Returns (startTime, endTime) in seconds if valid, or sets validationError and returns nil.
    private func validate() -> (TimeInterval, TimeInterval)? {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Name cannot be empty."
            return nil
        }
        guard let start = TimeFormatter.parse(startTimeText) else {
            validationError = "Start time format is invalid. Use mm:ss (e.g. 1:30)."
            return nil
        }
        guard let end = TimeFormatter.parse(endTimeText) else {
            validationError = "End time format is invalid. Use mm:ss (e.g. 2:45)."
            return nil
        }
        guard start >= 0 else {
            validationError = "Start time must be 0:00 or later."
            return nil
        }
        guard end > start else {
            validationError = "End time must be after start time."
            return nil
        }
        guard end <= audioDuration else {
            validationError = "End time exceeds the audio file duration."
            return nil
        }
        validationError = nil
        return (start, end)
    }
}
