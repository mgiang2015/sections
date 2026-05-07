import Foundation
import AVFoundation
import Combine
import SwiftData

/// Manages all audio playback state using AVFoundation.
/// Supports background audio playback — audio continues when the app is backgrounded.
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

            // numberOfLoops = -1 loops the ENTIRE FILE, not a section.
            // Section boundary enforcement must be done via the timer tick.
            // Set to 0 so the file plays through and the delegate fires if
            // the timer somehow misses the end (belt-and-suspenders).
            player.numberOfLoops = 0
            player.currentTime = section.startTime
            player.rate = playbackRate
            player.play()
            isPlaying = true
            section.lastPlayed = Date()

            startSectionTimer()
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
            startSectionTimer()
        }
    }

    func replay() {
        guard let player else { return }
        player.currentTime = sectionStartTime
        if !isPlaying {
            player.play()
            isPlaying = true
            startSectionTimer()
        }
    }

    func seekWithinSection(by seconds: TimeInterval) {
        guard let player else { return }
        let target = max(sectionStartTime, min(sectionEndTime, player.currentTime + seconds))
        player.currentTime = target
    }

    func togglePlaybackMode() {
        currentPlaybackMode = currentPlaybackMode == .loop ? .playOnce : .loop
        activeSection?.playbackMode = currentPlaybackMode
    }

    // MARK: - Private Helpers

    private func applyRate() {
        player?.rate = playbackRate
    }

    /// Starts the section timer.
    /// Fires at 50ms intervals — handles both progress bar updates AND section boundary
    /// enforcement (loop / stop at sectionEndTime).
    /// Uses .common RunLoop mode so it fires during touch tracking and UI animation.
    /// NOTE: When the app is backgrounded the main RunLoop is suspended, so the timer
    /// will not fire. However AVAudioSession's .playback category keeps the audio thread
    /// alive, so audio continues — the timer simply resumes when the app foregrounds.
    /// The section boundary is enforced immediately on the next tick after foregrounding.
    private func startSectionTimer() {
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
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

        // Section boundary enforcement
        if current >= sectionEndTime {
            switch currentPlaybackMode {
            case .loop:
                player.currentTime = sectionStartTime
                // Re-call play() to ensure the player is still running after the seek
                if !player.isPlaying { player.play() }

            case .playOnce:
                player.pause()
                player.currentTime = sectionStartTime
                isPlaying = false
                progress = 0
                stopTimer()
            }
        }
    }

    // MARK: - Interruption Handling

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
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
            if isPlaying {
                player?.pause()
                isPlaying = false
                stopTimer()
            }

        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                AudioSessionManager.shared.reactivate()
                player?.play()
                isPlaying = true
                startSectionTimer()
            }

        @unknown default:
            break
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension PlaybackViewModel: AVAudioPlayerDelegate {

    /// Belt-and-suspenders: if the timer somehow misses the section end and
    /// the file plays all the way through, catch it here and loop/stop.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        Task { @MainActor in
            switch self.currentPlaybackMode {
            case .loop:
                player.currentTime = self.sectionStartTime
                player.play()
            case .playOnce:
                self.isPlaying = false
                self.progress = 0
                self.stopTimer()
            }
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
