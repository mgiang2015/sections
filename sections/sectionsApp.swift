import SwiftUI
import SwiftData

@main
struct SectionsApp: App {

    var body: some Scene {
        WindowGroup {
            AudioLibraryView()
                .modelContainer(for: [AudioFile.self, AudioSection.self])
        }
    }
}
