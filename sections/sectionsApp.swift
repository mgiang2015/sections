import SwiftUI
import SwiftData

@main
struct SectionsApp: App {

    init() {
        // Activate audio session at launch so background playback works
        // from the very first time the user plays a section.
        AudioSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            AudioLibraryView()
                .modelContainer(for: [AudioFile.self, AudioSection.self])
        }
    }
}
