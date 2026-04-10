//
//  LiveMarkingViewModel.swift
//  sections
//
//  Created by Minh Giang Le on 10/4/26.
//

import Foundation
import Combine

/// Manages the step-by-step state machine for live timestamp marking.
/// Extracted from LiveMarkingView so the logic can be unit tested independently.
@MainActor
final class LiveMarkingViewModel: ObservableObject {

    // MARK: - Step

    enum MarkingStep: Equatable {
        case start
        case end
        case done
    }

    // MARK: - Published State

    @Published private(set) var step: MarkingStep = .start
    @Published private(set) var markedStart: TimeInterval? = nil
    @Published private(set) var markedEnd: TimeInterval? = nil
    @Published private(set) var markError: String? = nil

    // MARK: - Computed

    var canConfirm: Bool {
        markedStart != nil && markedEnd != nil
    }

    var stepTitle: String {
        switch step {
        case .start: return "Step 1 — Mark Start"
        case .end:   return "Step 2 — Mark End"
        case .done:  return "Both timestamps marked"
        }
    }

    var stepSubtitle: String {
        switch step {
        case .start: return "Play the audio and tap Mark Start at the right moment"
        case .end:   return "Continue playing and tap Mark End when the section finishes"
        case .done:  return "Tap Use to apply, or tap Mark Start again to redo"
        }
    }

    var markButtonLabel: String {
        switch step {
        case .start: return "Mark Start"
        case .end:   return "Mark End"
        case .done:  return "Re-mark Start"
        }
    }

    // MARK: - Actions

    /// Called when the user taps the Mark button at the given current playback time.
    func mark(at currentTime: TimeInterval) {
        markError = nil

        switch step {
        case .start:
            markedStart = currentTime
            markedEnd = nil          // clear end whenever start is re-marked
            step = .end

        case .end:
            guard let start = markedStart, currentTime > start else {
                markError = "End must be after start. Keep playing and try again."
                return
            }
            markedEnd = currentTime
            step = .done

        case .done:
            // Allow full redo
            markedStart = nil
            markedEnd = nil
            step = .start
        }
    }

    /// Validates and returns the final (start, end) pair, or sets markError and returns nil.
    func confirm() -> (TimeInterval, TimeInterval)? {
        guard let start = markedStart, let end = markedEnd else {
            markError = "Both timestamps must be marked before confirming."
            return nil
        }
        guard end > start else {
            markError = "End must be after start."
            return nil
        }
        return (start, end)
    }

    /// Resets all state back to initial — used when the sheet is cancelled.
    func reset() {
        step = .start
        markedStart = nil
        markedEnd = nil
        markError = nil
    }
}
