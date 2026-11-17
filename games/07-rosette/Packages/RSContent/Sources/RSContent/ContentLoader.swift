// RSContent — Content loaders and validators for Rosette.

import Foundation
import RSCore

// MARK: - ContentLoader

/// Loads typed content from JSON files bundled with the app.
public struct ContentLoader {
    private let bundle: Bundle

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    /// Create a loader with the module bundle.
    public init() {
        self.init(bundle: .module)
    }

    /// Load all tavern definitions.
    public func loadTaverns() throws -> [TavernDef] {
        try loadJSON("taverns.json")
    }

    /// Load all opponent definitions.
    public func loadOpponents() throws -> [OpponentDef] {
        try loadJSON("opponents.json")
    }

    /// Load all omen definitions.
    public func loadOmens() throws -> [OmenDef] {
        try loadJSON("omens.json")
    }

    /// Load all ruleset definitions.
    public func loadRulesets() throws -> [RulesetDef] {
        try loadJSON("rulesets.json")
    }

    /// Load tutorial lessons.
    public func loadTutorial() throws -> [TutorialLessonDef] {
        try loadJSON("tutorial.json")
    }

    /// Load balance data.
    public func loadBalance() throws -> BalanceDef {
        try loadJSON("balance.json")
    }

    /// Validate referential integrity across all content.
    public func validateAll() throws -> ValidationResult {
        let taverns = try loadTaverns()
        let opponents = try loadOpponents()
        let omens = try loadOmens()
        let rulesets = try loadRulesets()
        let tutorial = try loadTutorial()

        var errors: [String] = []

        // Check tavern IDs are unique
        let tavernIds = taverns.map { $0.id }
        if tavernIds.count != Set(tavernIds).count {
            errors.append("Duplicate tavern IDs found")
        }

        // Check opponent tavern references
        let tavernIdSet = Set(tavernIds)
        for opponent in opponents {
            if !tavernIdSet.contains(opponent.tavernId) {
                errors.append("Opponent '\(opponent.id)' references unknown tavern '\(opponent.tavernId)'")
            }
        }

        // Check ruleset IDs are unique
        let rulesetIds = rulesets.map { $0.id }
        if rulesetIds.count != Set(rulesetIds).count {
            errors.append("Duplicate ruleset IDs found")
        }

        // Check tutorial ruleset references
        let rulesetIdSet = Set(rulesetIds)
        for lesson in tutorial {
            if !rulesetIdSet.contains(lesson.rulesetId) {
                errors.append("Tutorial lesson '\(lesson.id)' references unknown ruleset '\(lesson.rulesetId)'")
            }
        }

        // Check omen IDs are unique
        let omenIds = omens.map { $0.id }
        if omenIds.count != Set(omenIds).count {
            errors.append("Duplicate omen IDs found")
        }

        return ValidationResult(errors: errors, taverns: taverns, opponents: opponents, omens: omens, rulesets: rulesets, tutorial: tutorial)
    }

    private func loadJSON<T: Decodable>(_ filename: String) throws -> T {
        guard let url = bundle.url(forResource: filename, withExtension: nil) else {
            throw ContentError.missingFile(filename)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - ValidationResult

/// Result of content validation.
public struct ValidationResult {
    public let errors: [String]
    public let taverns: [TavernDef]
    public let opponents: [OpponentDef]
    public let omens: [OmenDef]
    public let rulesets: [RulesetDef]
    public let tutorial: [TutorialLessonDef]

    /// Whether validation passed (no errors).
    public var isValid: Bool {
        errors.isEmpty
    }
}

// MARK: - ContentError

enum ContentError: Error, CustomStringConvertible {
    case missingFile(String)
    case decodeError(Error)
    case validationErrors([String])

    var description: String {
        switch self {
        case .missingFile(let name):
            return "Missing content file: \(name)"
        case .decodeError(let error):
            return "Content decode error: \(error)"
        case .validationErrors(let errors):
            return "Content validation errors: \(errors.joined(separator: ", "))"
        }
    }
}
