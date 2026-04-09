import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

/// Home screen — lists all imported MP3 audio files, sorted by date added (newest first).
struct AudioLibraryView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AudioFile.dateAdded, order: .reverse) private var audioFiles: [AudioFile]

    @State private var isImporting = false
    @State private var fileToDelete: AudioFile?
    @State private var showDeleteConfirmation = false
    @State private var importError: String?
    @State private var showImportError = false

    // ViewModel handles file import logic
    @State private var viewModel = AudioLibraryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if audioFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .navigationTitle("Sections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import audio file")
                }
            }
            // MP3 file picker
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.mp3],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
            .confirmationDialog(
                "Delete Audio File",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let file = fileToDelete {
                        viewModel.deleteAudioFile(file, context: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the file and all its sections from the app. The original file in your Files app will not be affected.")
            }
        }
    }

    // MARK: - Subviews

    private var fileList: some View {
        List {
            ForEach(audioFiles) { file in
                NavigationLink(destination: SectionsListView(audioFile: file)) {
                    AudioFileRowView(audioFile: file)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    fileToDelete = audioFiles[index]
                    showDeleteConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Audio Files")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to import an MP3 from your Files app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import MP3") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helpers

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try viewModel.importAudioFile(from: url, existingFiles: audioFiles, context: modelContext)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }
}
