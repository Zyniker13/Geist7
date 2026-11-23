import Foundation

/// Launch-argument parsing for UI-test and snapshot scenarios
/// (-startMatch -seed N -debugOverlay -scenario NAME).
///
/// Parsing takes an explicit argument list so unit tests can exercise
/// it without mutating ProcessInfo. P0 scenarios are placeholders; the
/// rules engine arrives in P1.
enum LaunchArguments {
    struct Parsed: Equatable {
        var startMatch = false
        var seed: UInt64?
        var debugOverlay = false
        var scenario: String?
    }

    static var current: Parsed {
        parse(ProcessInfo.processInfo.arguments)
    }

    static func parse(_ arguments: [String]) -> Parsed {
        var result = Parsed()
        var index = 0
        func nextValue() -> String? {
            index += 1
            return index < arguments.count ? arguments[index] : nil
        }
        while index < arguments.count {
            switch arguments[index] {
            case "-startMatch":
                result.startMatch = true
            case "-seed":
                result.seed = nextValue().flatMap(UInt64.init)
            case "-debugOverlay":
                result.debugOverlay = true
            case "-scenario":
                result.scenario = nextValue()
            default:
                break
            }
            index += 1
        }
        return result
    }
}
