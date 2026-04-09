import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

/// Displays all sections for a given audio file, sorted by lastPlayed descending.
struct SectionsListView: View {

    @Environment(\.modelContext) private var modelContext
    let audioFile: AudioFile

    @State private var showCreateSheet = false
    @State private var sectionToEdit: AudioSection?
    @State private var sectionToDelete: AudioSection?
    @State private var showDeleteConfirmation = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var importError: String?
    @State private var showImportError = false

    @StateObject private var playbackViewModel = PlaybackViewModel()
    @State private var exportImportViewModel = ExportImportViewModel()

    private var sortedSections: [AudioSection] {
        audioFile.sectionsSortedByLastPlayed
    }

    var body: some View {
        Group {
            if sortedSections.isEmpty {
                emptyState
            } else {
                sectionList
            }
        }
        .navigationTitle(audioFile.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // Create section sheet
        .sheet(isPresented: $showCreateSheet) {
            SectionFormView(audioFile: audioFile, existingSection: nil)
        }
        // Edit section sheet
        .sheet(item: $sectionToEdit) { section in
            SectionFormView(audioFile: audioFile, existingSection: section)
        }
        // Delete confirmation
        .confirmationDialog("Delete Section", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let section = sectionToDelete {
                    modelContext.delete(section)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(sectionToDelete?.name ?? "this section")\"?")
        }
        // JSON export share sheet
        .sheet(isPresented: $isExporting) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        // JSON import file picker
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImportResult(result)
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Subviews

    private var sectionList: some View {
        List {
            ForEach(sortedSections) { section in
                SectionRowView(section: section, isPlaying: playbackViewModel.activeSection?.id == section.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playbackViewModel.play(section: section, from: audioFile)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            sectionToDelete = section
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            sectionToEdit = section
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scissors")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Sections Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to define your first section.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add Section") { showCreateSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showCreateSheet = true } label: {
                    Label("Add Section", systemImage: "plus")
                }
                Divider()
                Button { triggerExport() } label: {
                    Label("Export Sections", systemImage: "square.and.arrow.up")
                }
                Button { isImporting = true } label: {
                    Label("Import Sections", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Helpers

    private func triggerExport() {
        do {
            exportURL = try exportImportViewModel.exportSections(for: audioFile)
            isExporting = true
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try exportImportViewModel.importSections(from: url, into: audioFile, context: modelContext)
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
