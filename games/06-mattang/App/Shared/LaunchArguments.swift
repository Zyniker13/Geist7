import Foundation

/// Launch-argument parsing for UI-test and snapshot scenarios
/// (-startMatch -seed N -autoPilot -scenario NAME -snapshotPly N).
///
/// Parsing takes an explicit argument list so unit tests can exercise
/// it without mutating ProcessInfo.
enum LaunchArguments {
    struct Parsed: Equatable {
        var startMatch = false
        var seed: UInt64?
        var autoPilot = false
        var scenario: String?
        var snapshotPly: Int?
        var debugOverlay = false
        var aiDelay: Double?
        /// MT-P3.3: local pass-and-play — both sides are human.
        var passAndPlay = false
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
            case "-autoPilot":
                result.autoPilot = true
            case "-passAndPlay":
                result.passAndPlay = true
            case "-scenario":
                result.scenario = nextValue()
            case "-snapshotPly":
                result.snapshotPly = nextValue().flatMap(Int.init)
            case "-debugOverlay":
                result.debugOverlay = true
            case "-aiDelay":
                result.aiDelay = nextValue().flatMap(Double.init)
            default:
                break
            }
            index += 1
        }
        return result
    }
}
