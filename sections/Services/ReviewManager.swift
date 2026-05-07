import StoreKit
import UIKit

/// Manages the timing and triggering of the in-app review prompt.
/// Prompts after a meaningful engagement threshold is reached,
/// and only once per app version to avoid annoying returning users.
final class ReviewManager {

    static let shared = ReviewManager()

    // MARK: - Constants

    private let playThreshold = 25

    // MARK: - UserDefaults Keys

    private let playCountKey           = "reviewManager.totalSectionPlays"
    private let lastReviewedVersionKey = "reviewManager.lastReviewedVersion"

    // MARK: - Dependencies (injectable for testing)

    private let defaults: UserDefaults
    private let currentVersion: String

    // MARK: - Init

    /// Production init — uses standard UserDefaults and the app's bundle version.
    init() {
        self.defaults = .standard
        self.currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Testable init — inject custom UserDefaults suite and version string.
    init(defaults: UserDefaults, currentVersion: String) {
        self.defaults = defaults
        self.currentVersion = currentVersion
    }

    // MARK: - Public API

    /// Call this every time a section begins playing.
    /// Increments the play counter and shows the review prompt when the threshold is reached.
    func recordSectionPlay() {
        let newCount = totalPlays + 1
        defaults.set(newCount, forKey: playCountKey)

        if shouldRequestReview(at: newCount) {
            requestReview()
        }
    }

    /// True if the review prompt has already been shown for the current app version.
    /// Exposed internally for testing.
    var hasRequestedReviewForCurrentVersion: Bool {
        defaults.string(forKey: lastReviewedVersionKey) == currentVersion
    }

    /// The total number of section plays recorded across all sessions.
    /// Exposed internally for testing.
    var totalPlays: Int {
        defaults.integer(forKey: playCountKey)
    }

    // MARK: - Private

    private func shouldRequestReview(at count: Int) -> Bool {
        guard count == playThreshold else { return false }
        guard !hasRequestedReviewForCurrentVersion else { return false }
        return true
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        // Mark this version as reviewed before presenting — prevents duplicate prompts
        // if the user plays another section before the dialog appears.
        defaults.set(currentVersion, forKey: lastReviewedVersionKey)

        // Brief delay so the prompt doesn't interrupt the play action
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            AppStore.requestReview(in: scene)
        }
    }
}
