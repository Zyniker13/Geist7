// Replay — deterministic game replay support

import Foundation

/// A single recorded event in a game replay.
public struct ReplayEvent: Codable, Sendable {
  public let turn: Int
  public let player: Int
  public let action: String
  public let params: [String: String]

  public init(turn: Int, player: Int, action: String, params: [String: String] = [:]) {
    self.turn = turn
    self.player = player
    self.action = action
    self.params = params
  }
}

/// A complete replay of a game.
public struct Replay: Codable, Sendable {
  public let seed: UInt64
  public let game: String
  public let events: [ReplayEvent]
  public let winner: Int?

  public init(seed: UInt64, game: String, events: [ReplayEvent], winner: Int?) {
    self.seed = seed
    self.game = game
    self.events = events
    self.winner = winner
  }

  /// Serialize to JSON Data.
  public func encode() -> Data? {
    try? JSONEncoder().encode(self)
  }

  /// Decode from JSON Data.
  public static func decode(_ data: Data) -> Replay? {
    try? JSONDecoder().decode(Replay.self, from: data)
  }

  /// Save to file.
  public func save(to url: URL) throws {
    guard let data = encode() else {
      throw ReplayError.encodeFailed
    }
    try data.write(to: url)
  }

  /// Load from file.
  public static func load(from url: URL) throws -> Replay {
    let data = try Data(contentsOf: url)
    guard let replay = decode(data) else {
      throw ReplayError.decodeFailed
    }
    return replay
  }
}

public enum ReplayError: Error {
  case encodeFailed
  case decodeFailed
}
