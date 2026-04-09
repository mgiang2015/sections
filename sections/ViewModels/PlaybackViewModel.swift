import Foundation
import AVFoundation
import Combine
import SwiftData

/// Manages all audio playback state using AVFoundation.
/// Shared as a @StateObject within SectionsListView.
@MainActor
final class PlaybackViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0        // 0.0 – 1.0 within the active section
    @Published var activeSection: AudioSection?
    @Published var currentPlaybackMode: PlaybackMode = .loop
    @Published var playbackRate: Float = 1.0 {
        didSet { applyRate() }
    }

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var sectionStartTime: TimeInterval = 0
    private var sectionEndTime: TimeInterval = 0
    private var progressTimer: Timer?

    // MARK: - Public API

    /// Begin playing a section from its startTime.
    func play(section: AudioSection, from audioFile: AudioFile) {
        stopTimer()

        do {
            // Re-use existing player if same file is already loaded
            if player?.url != audioFile.resolvedURL {
                player = try AVAudioPlayer(contentsOf: audioFile.resolvedURL)
                // Enable pitch-preserving rate changes (BRD §4.5)
                player?.enableRate = true
            }
            guard let player else { return }

            activeSection = section
            currentPlaybackMode = section.playbackMode
            sectionStartTime = section.startTime
            sectionEndTime   = section.endTime

            player.currentTime = section.startTime
            player.rate = playbackRate
            player.play()
            isPlaying = true

            // Update lastPlayed timestamp
            section.lastPlayed = Date()

            startTimer()
        } catch {
            // TODO: Surface error to the UI via an error publisher in a future sprint
            print("AVAudioPlayer error: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func replay() {
        guard let player else { return }
        player.currentTime = sectionStartTime
        if !isPlaying {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func togglePlaybackMode() {
        currentPlaybackMode = currentPlaybackMode == .loop ? .playOnce : .loop
        activeSection?.playbackMode = currentPlaybackMode
    }

    // MARK: - Private Helpers

    private func applyRate() {
        player?.rate = playbackRate
    }

    private func startTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tick() {
        guard let player, isPlaying else { return }

        let current = player.currentTime
        let sectionDuration = sectionEndTime - sectionStartTime

        // Update progress bar
        if sectionDuration > 0 {
            progress = max(0, min(1, (current - sectionStartTime) / sectionDuration))
        }

        // Check if section has ended
        if current >= sectionEndTime {
            switch currentPlaybackMode {
            case .loop:
                player.currentTime = sectionStartTime
                player.play()
            case .playOnce:
                player.pause()
                player.currentTime = sectionStartTime
                isPlaying = false
                progress = 0
                stopTimer()
            }
        }
    }
}
