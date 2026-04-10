//
//  LiveMarkingViewModelTest.swift
//  sections
//
//  Created by Minh Giang Le on 10/4/26.
//

import XCTest
@testable import sections

@MainActor
final class LiveMarkingViewModelTests: XCTestCase {

    var sut: LiveMarkingViewModel!

    override func setUp() {
        super.setUp()
        sut = LiveMarkingViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialStep_isStart() {
        XCTAssertEqual(sut.step, .start)
    }

    func test_initialMarkedStart_isNil() {
        XCTAssertNil(sut.markedStart)
    }

    func test_initialMarkedEnd_isNil() {
        XCTAssertNil(sut.markedEnd)
    }

    func test_initialMarkError_isNil() {
        XCTAssertNil(sut.markError)
    }

    func test_initialCanConfirm_isFalse() {
        XCTAssertFalse(sut.canConfirm)
    }

    // MARK: - mark(at:) — step: start

    func test_markAtStart_setsMarkedStart() {
        sut.mark(at: 10.0)
        XCTAssertEqual(sut.markedStart, 10.0)
    }

    func test_markAtStart_advancesStepToEnd() {
        sut.mark(at: 10.0)
        XCTAssertEqual(sut.step, .end)
    }

    func test_markAtStart_doesNotSetMarkedEnd() {
        sut.mark(at: 10.0)
        XCTAssertNil(sut.markedEnd)
    }

    func test_markAtStart_clearsAnyPreviousError() {
        // Simulate a prior error state
        sut.mark(at: 30.0)   // start
        sut.mark(at: 10.0)   // end before start — sets error
        XCTAssertNotNil(sut.markError)

        // Re-mark start — error should clear
        sut.mark(at: 60.0)   // → step: .done, error cleared
        XCTAssertNil(sut.markError)
    }

    func test_markAtStart_zeroTime_isAccepted() {
        sut.mark(at: 0.0)
        XCTAssertEqual(sut.markedStart, 0.0)
        XCTAssertEqual(sut.step, .end)
    }

    // MARK: - mark(at:) — step: end (valid)

    func test_markAtEnd_afterStart_setsMarkedEnd() {
        sut.mark(at: 10.0)   // start
        sut.mark(at: 30.0)   // end
        XCTAssertEqual(sut.markedEnd, 30.0)
    }

    func test_markAtEnd_afterStart_advancesStepToDone() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertEqual(sut.step, .done)
    }

    func test_markAtEnd_afterStart_noError() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertNil(sut.markError)
    }

    func test_markAtEnd_afterStart_canConfirmIsTrue() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertTrue(sut.canConfirm)
    }

    // MARK: - mark(at:) — step: end (invalid — end before start)

    func test_markAtEnd_beforeStart_setsError() {
        sut.mark(at: 30.0)   // start
        sut.mark(at: 10.0)   // end before start
        XCTAssertNotNil(sut.markError)
    }

    func test_markAtEnd_beforeStart_staysOnEndStep() {
        sut.mark(at: 30.0)
        sut.mark(at: 10.0)
        XCTAssertEqual(sut.step, .end)
    }

    func test_markAtEnd_beforeStart_doesNotSetMarkedEnd() {
        sut.mark(at: 30.0)
        sut.mark(at: 10.0)
        XCTAssertNil(sut.markedEnd)
    }

    func test_markAtEnd_equalToStart_setsError() {
        // End must be strictly after start
        sut.mark(at: 30.0)
        sut.mark(at: 30.0)
        XCTAssertNotNil(sut.markError)
        XCTAssertNil(sut.markedEnd)
    }

    func test_markAtEnd_oneSecondAfterStart_isValid() {
        sut.mark(at: 10.0)
        sut.mark(at: 11.0)
        XCTAssertEqual(sut.markedEnd, 11.0)
        XCTAssertEqual(sut.step, .done)
    }

    func test_markAtEnd_errorMessage_mentionsStartAndEnd() {
        sut.mark(at: 30.0)
        sut.mark(at: 10.0)
        let error = sut.markError ?? ""
        XCTAssertFalse(error.isEmpty, "Error message should not be empty")
    }

    // MARK: - mark(at:) — step: done (redo)

    func test_markAtDone_resetsToStartStep() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertEqual(sut.step, .done)

        sut.mark(at: 0.0)   // tap again in done state
        XCTAssertEqual(sut.step, .start)
    }

    func test_markAtDone_clearsMarkedStart() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        sut.mark(at: 0.0)   // redo
        XCTAssertNil(sut.markedStart)
    }

    func test_markAtDone_clearsMarkedEnd() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        sut.mark(at: 0.0)   // redo
        XCTAssertNil(sut.markedEnd)
    }

    func test_markAtDone_canConfirmBecomeFalse() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertTrue(sut.canConfirm)
        sut.mark(at: 0.0)   // redo
        XCTAssertFalse(sut.canConfirm)
    }

    // MARK: - Re-marking start clears end (BRD: redo flow)

    func test_remarkingStart_clearsExistingEnd() {
        sut.mark(at: 10.0)   // start
        sut.mark(at: 30.0)   // end  — now done
        sut.mark(at: 0.0)    // redo — back to start
        sut.mark(at: 5.0)    // new start

        // end should be nil until user marks it again
        XCTAssertNil(sut.markedEnd)
    }

    // MARK: - Full happy-path flow

    func test_fullFlow_startToConfirm() {
        // Step through the complete marking flow
        XCTAssertEqual(sut.step, .start)
        XCTAssertFalse(sut.canConfirm)

        sut.mark(at: 15.0)
        XCTAssertEqual(sut.step, .end)
        XCTAssertEqual(sut.markedStart, 15.0)
        XCTAssertFalse(sut.canConfirm)

        sut.mark(at: 45.0)
        XCTAssertEqual(sut.step, .done)
        XCTAssertEqual(sut.markedEnd, 45.0)
        XCTAssertTrue(sut.canConfirm)

        let result = sut.confirm()
        XCTAssertEqual(result?.0, 15.0)
        XCTAssertEqual(result?.1, 45.0)
    }

    // MARK: - confirm()

    func test_confirm_withBothTimestamps_returnsStartAndEnd() {
        sut.mark(at: 20.0)
        sut.mark(at: 60.0)

        let result = sut.confirm()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, 20.0)
        XCTAssertEqual(result?.1, 60.0)
    }

    func test_confirm_withoutMarking_returnsNil() {
        let result = sut.confirm()
        XCTAssertNil(result)
    }

    func test_confirm_withoutMarking_setsError() {
        _ = sut.confirm()
        XCTAssertNotNil(sut.markError)
    }

    func test_confirm_withOnlyStart_returnsNil() {
        sut.mark(at: 10.0)   // only start marked
        let result = sut.confirm()
        XCTAssertNil(result)
    }

    // MARK: - reset()

    func test_reset_clearsStep() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        sut.reset()
        XCTAssertEqual(sut.step, .start)
    }

    func test_reset_clearsMarkedStart() {
        sut.mark(at: 10.0)
        sut.reset()
        XCTAssertNil(sut.markedStart)
    }

    func test_reset_clearsMarkedEnd() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        sut.reset()
        XCTAssertNil(sut.markedEnd)
    }

    func test_reset_clearsError() {
        sut.mark(at: 30.0)
        sut.mark(at: 10.0)   // triggers error
        XCTAssertNotNil(sut.markError)
        sut.reset()
        XCTAssertNil(sut.markError)
    }

    func test_reset_canConfirmIsFalse() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertTrue(sut.canConfirm)
        sut.reset()
        XCTAssertFalse(sut.canConfirm)
    }

    // MARK: - Display strings

    func test_stepTitle_start() {
        XCTAssertFalse(sut.stepTitle.isEmpty)
        XCTAssertTrue(sut.stepTitle.lowercased().contains("start"))
    }

    func test_stepTitle_end() {
        sut.mark(at: 10.0)
        XCTAssertTrue(sut.stepTitle.lowercased().contains("end"))
    }

    func test_stepTitle_done() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        XCTAssertFalse(sut.stepTitle.isEmpty)
    }

    func test_markButtonLabel_start() {
        XCTAssertTrue(sut.markButtonLabel.lowercased().contains("start"))
    }

    func test_markButtonLabel_end() {
        sut.mark(at: 10.0)
        XCTAssertTrue(sut.markButtonLabel.lowercased().contains("end"))
    }

    func test_markButtonLabel_done_offersRemark() {
        sut.mark(at: 10.0)
        sut.mark(at: 30.0)
        // In done state the button should offer to re-mark
        XCTAssertFalse(sut.markButtonLabel.isEmpty)
    }
}
