import SwiftUI
import AVFoundation
import SwiftData

/// Modal form for creating or editing an AudioSection.
/// Pass `existingSection: nil` to create a new one.
/// Pass `playbackViewModel` to enable live tap-to-mark timestamps.
struct SectionFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let audioFile: AudioFile
    var existingSection: AudioSection?

    /// Shared playback engine from SectionsListView.
    /// When provided, the "Mark Live" button is enabled.
    var playbackViewModel: PlaybackViewModel? = nil

    // MARK: - Form State

    @State private var name: String = ""
    @State private var startTimeText: String = "0:00"
    @State private var endTimeText: String = "0:00"
    @State private var playbackMode: PlaybackMode = .loop
    @State private var validationError: String?
    @State private var showLiveMarking = false
    @State private var audioDuration: TimeInterval = 15 * 60   // updated onAppear

    private var isEditing: Bool { existingSection != nil }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Name") {
                    TextField("e.g. Chorus, Verse 1", text: $name)
                        .autocorrectionDisabled()
                }

                SwiftUI.Section {
                    // Live marking button — only shown when a player is available
                    if playbackViewModel != nil {
                        Button {
                            showLiveMarking = true
                        } label: {
                            HStack {
                                Image(systemName: "record.circle")
                                    .foregroundStyle(.red)
                                Text("Mark with Audio")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    
                    // Manual timestamp fields
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
                    Text("Format: mm:ss  (e.g. 1:30)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Timestamps")
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
            .onAppear {
                populateIfEditing()
                loadAudioDuration()
            }
            // Live marking sheet
            .sheet(isPresented: $showLiveMarking) {
                if let vm = playbackViewModel {
                    LiveMarkingView(
                        playbackViewModel: vm,
                        audioFile: audioFile
                    ) { start, end in
                        // Callback: apply marked timestamps to the form fields
                        startTimeText = TimeFormatter.format(start)
                        endTimeText   = TimeFormatter.format(end)
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let section = existingSection else { return }
        name          = section.name
        startTimeText = TimeFormatter.format(section.startTime)
        endTimeText   = TimeFormatter.format(section.endTime)
        playbackMode  = section.playbackMode
    }

    private func loadAudioDuration() {
        Task {
            if let duration = await AudioFileService.duration(of: audioFile.resolvedURL) {
                audioDuration = duration
            }
        }
    }

    private func save() {
        guard let (start, end) = validate() else { return }

        if let section = existingSection {
            section.name         = name.trimmingCharacters(in: .whitespaces)
            section.startTime    = start
            section.endTime      = end
            section.playbackMode = playbackMode
        } else {
            let newSection = AudioSection(
                name: name.trimmingCharacters(in: .whitespaces),
                startTime: start,
                endTime: end,
                playbackMode: playbackMode
            )
            newSection.audioFile = audioFile
            modelContext.insert(newSection)
        }

        dismiss()
    }

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
