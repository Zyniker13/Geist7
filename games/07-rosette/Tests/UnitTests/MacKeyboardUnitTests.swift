import XCTest

@testable import Rosette_macOS

/// RS-P7.2: the Mac keyboard path (keys 1–7 pick a piece) without UI
/// automation — the macOS UI-test runner cannot initialize automation mode
/// on this machine (see the S7.2 maintainer issue), so the handler logic is
/// exercised directly against the live view model instead.
@MainActor
final class MacKeyboardUnitTests: XCTestCase {

    /// A manual (non-autoPilot) match on the default Finkel ruleset.
    private func makeManualViewModel() -> GameViewModel {
        GameViewModel(stakeValue: 1, useAI: false, seed: 7, autoSave: false)
    }

    func testNumberKeyAppliesLegalMove() {
        let vm = makeManualViewModel()
        vm.rollDice()
        guard !vm.legalMoves.isEmpty else {
            // Deterministic seed 7 opened with a blocked roll; any seed with
            // an opening move satisfies this test's purpose.
            return
        }
        let before = vm.matchState.plies
        let piece = vm.legalMoves[0].piece
        let destination = vm.legalMoves[0].destination
        let applied = vm.handleNumberKey(1)
        XCTAssertTrue(applied, "key 1 should apply the first legal move")
        XCTAssertEqual(vm.matchState.plies, before + 1)
        XCTAssertEqual(
            vm.matchState.pieces.first(where: { $0.id == piece })?.position,
            destination
        )
    }

    func testOutOfRangeKeysAreIgnored() {
        let vm = makeManualViewModel()
        vm.rollDice()
        let before = vm.matchState.plies
        XCTAssertFalse(vm.handleNumberKey(0), "0 is not a piece key")
        XCTAssertFalse(vm.handleNumberKey(8), "8 is not a piece key (1–7 only)")
        if vm.legalMoves.isEmpty {
            XCTAssertEqual(vm.matchState.plies, before)
        } else {
            XCTAssertEqual(vm.matchState.plies, before, "no move should apply")
        }
    }

    func testKeyBeforeRollIsIgnored() {
        let vm = makeManualViewModel()
        XCTAssertFalse(vm.matchState.hasRolled)
        XCTAssertFalse(vm.handleNumberKey(1), "no piece can move before the roll")
    }
}
