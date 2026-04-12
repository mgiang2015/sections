//
//  AudioSessionManager.swift
//  sections
//
//  Created by Minh Giang Le on 12/4/26.
//

import AVFoundation

/// Configures and manages the app's AVAudioSession for background audio playback.
/// Must be activated before any playback begins.
final class AudioSessionManager {

    static let shared = AudioSessionManager()
    private init() {}

    /// Activates the audio session with the `.playback` category.
    /// Call once at app launch from SectionsApp.
    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback category allows audio to continue when the app is backgrounded
            // and when the silent/mute switch is engaged.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession activation failed: \(error)")
        }
    }

    /// Reactivates the session after an interruption (e.g. phone call ended).
    func reactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession reactivation failed: \(error)")
        }
    }
}
