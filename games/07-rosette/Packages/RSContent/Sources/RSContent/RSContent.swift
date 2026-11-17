// RSContent — Content types, loaders, and validators for Rosette.

// MARK: - Public API

/// Load all game content from bundled JSON files.
@MainActor
public func loadAllContent() throws -> ValidationResult {
    try ContentLoader().validateAll()
}

/// Load a single content type by name.
@MainActor
public func loadContent(named type: String) throws -> Any {
    let loader = ContentLoader()
    switch type {
    case "taverns":
        return try loader.loadTaverns()
    case "opponents":
        return try loader.loadOpponents()
    case "omens":
        return try loader.loadOmens()
    case "rulesets":
        return try loader.loadRulesets()
    case "tutorial":
        return try loader.loadTutorial()
    case "balance":
        return try loader.loadBalance()
    default:
        throw ContentError.missingFile(type)
    }
}
