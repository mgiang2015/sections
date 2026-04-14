import Foundation
import AVFoundation
import Combine
import SwiftData

/// Manages all audio playback state using AVFoundation.
/// Supports background audio playback — audio continues when the app is backgrounded.
/// Uses AVAudioPlayerDelegate for section-end detection so looping works with the screen off.
@MainActor
final class PlaybackViewModel: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0
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

    // Interruption observer (phone calls, Siri, alarms)
    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Init / Deinit

    override init() {
        super.init()
        observeInterruptions()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Begin playing a section from its startTime.
    func play(section: AudioSection, from audioFile: AudioFile) {
        stopTimer()

        do {
            if player?.url != audioFile.resolvedURL {
                player = try AVAudioPlayer(contentsOf: audioFile.resolvedURL)
                player?.enableRate = true
                player?.delegate = self
            }
            guard let player else { return }

            activeSection = section
            currentPlaybackMode = section.playbackMode
            sectionStartTime = section.startTime
            sectionEndTime   = section.endTime

            // Set numberOfLoops = -1 for infinite loop, 0 for play-once.
            // AVAudioPlayer handles looping natively — no timer needed for the loop itself.
            // This means looping continues even when the app is backgrounded.
            player.numberOfLoops = section.playbackMode == .loop ? -1 : 0
            player.currentTime = section.startTime
            player.rate = playbackRate
            player.play()
            isPlaying = true
            section.lastPlayed = Date()

            // Timer is only used for UI progress bar updates.
            // Section-end detection for .playOnce is handled by AVAudioPlayerDelegate.
            startProgressTimer()
        } catch {
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
            startProgressTimer()
        }
    }

    func replay() {
        guard let player else { return }
        player.currentTime = sectionStartTime
        if !isPlaying {
            player.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    /// Seeks forward or backward within the active section by the given number of seconds.
    /// Clamps to [sectionStartTime, sectionEndTime] so seeking never leaves the section.
    func seekWithinSection(by seconds: TimeInterval) {
        guard let player else { return }
        let target = max(sectionStartTime, min(sectionEndTime, player.currentTime + seconds))
        player.currentTime = target
    }

    func togglePlaybackMode() {
        currentPlaybackMode = currentPlaybackMode == .loop ? .playOnce : .loop
        activeSection?.playbackMode = currentPlaybackMode
        // Update numberOfLoops on the live player so the change takes effect immediately
        player?.numberOfLoops = currentPlaybackMode == .loop ? -1 : 0
    }

    // MARK: - Private Helpers

    private func applyRate() {
        player?.rate = playbackRate
    }

    private func startProgressTimer() {
        // Timer fires every 0.1s to update the UI progress bar only.
        // Using .common RunLoop mode so it fires while UI is tracking touches.
        // Background looping does NOT depend on this timer.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickProgress()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tickProgress() {
        guard let player, isPlaying else { return }

        let current = player.currentTime
        let sectionDuration = sectionEndTime - sectionStartTime

        if sectionDuration > 0 {
            progress = max(0, min(1, (current - sectionStartTime) / sectionDuration))
        }
    }

    // MARK: - Interruption Handling

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            // Extract only the Sendable UInt values we need before crossing
            // the Task boundary — neither Notification nor [AnyHashable: Any] is Sendable.
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            // Phone call, Siri, alarm started — pause playback
            if isPlaying {
                player?.pause()
                isPlaying = false
                stopTimer()
            }

        case .ended:
            // Interruption ended — resume if appropriate
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                AudioSessionManager.shared.reactivate()
                player?.play()
                isPlaying = true
                startProgressTimer()
            }

        @unknown default:
            break
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension PlaybackViewModel: AVAudioPlayerDelegate {

    /// Called by AVAudioPlayer when playback finishes naturally (numberOfLoops reached).
    /// For .loop mode this is never called (numberOfLoops = -1).
    /// For .playOnce this fires when the full file finishes — we use it to reset UI state.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        Task { @MainActor in
            // .playOnce: player finished the file — reset to section start
            self.player?.currentTime = self.sectionStartTime
            self.isPlaying = false
            self.progress = 0
            self.stopTimer()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
            print("AVAudioPlayer decode error: \(String(describing: error))")
        }
    }
}

// MARK: - Live Marking Support

extension PlaybackViewModel {

    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    func playFromBeginning(audioFile: AudioFile) {
        stopTimer()
        do {
            if player?.url != audioFile.resolvedURL {
                player = try AVAudioPlayer(contentsOf: audioFile.resolvedURL)
                player?.enableRate = true
                player?.delegate = self
            }
            guard let player else { return }
            player.numberOfLoops = 0
            player.currentTime = 0
            player.rate = playbackRate
            player.play()
            isPlaying = true
            startFreeTimer()
        } catch {
            print("AVAudioPlayer error: \(error)")
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = max(0, min(time, duration))
    }

    func stopAndReset() {
        player?.stop()
        isPlaying = false
        activeSection = nil
        progress = 0
        stopTimer()
    }

    private func startFreeTimer() {
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.progress = self.duration > 0 ? player.currentTime / self.duration : 0
                self.objectWillChange.send()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }
}
