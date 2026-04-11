import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

/// Home screen — lists all imported audio files with user-selectable sort order.
struct AudioLibraryView: View {

    @Environment(\.modelContext) private var modelContext
    // Fetch all files unsorted — sorting is done in-memory so the order can be
    // changed at runtime without re-querying SwiftData.
    @Query private var audioFiles: [AudioFile]

    @State private var sortOrder: LibrarySortOrder = .recentlyAdded
    @State private var isImporting = false
    @State private var fileToDelete: AudioFile?
    @State private var showDeleteConfirmation = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var viewModel = AudioLibraryViewModel()

    private var sortedFiles: [AudioFile] {
        sortOrder.sort(audioFiles)
    }

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
            .toolbar { toolbarContent }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: AudioLibraryViewModel.supportedContentTypes,
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
            ForEach(sortedFiles) { file in
                NavigationLink(destination: SectionsListView(audioFile: file)) {
                    AudioFileRowView(audioFile: file)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    fileToDelete = sortedFiles[index]
                    showDeleteConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: sortOrder)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Audio Files")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to import an MP3, WAV, or M4A file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import Audio") { isImporting = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Sort menu — left side
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Label(order.displayName, systemImage: order.systemImage)
                            .tag(order)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOrder.displayName)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }
            .accessibilityLabel("Sort order: \(sortOrder.displayName)")
        }
        // Import button — right side
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { isImporting = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Import audio file")
        }
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
