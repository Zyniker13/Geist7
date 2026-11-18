// RSRender — P6 (RS-P6.1): per-region board art themes.
//
// RESEARCH.md §1 pins the Ur palette: lapis #26428B, shell #EFE6D2, red
// limestone #A0422D, bitumen #2B2620, gold #C9A44C; materials are shell
// inlay, lapis chips, bitumen bedding, and worn wood. The Thebes and
// Tenochtitlan palettes are reconstruction-inspired (ADR-0013): each uses
// its culture's characteristic materials — limestone, papyrus, and
// turquoise for Thebes; obsidian, turquoise, jade, and cinnabar for
// Tenochtitlan — in the same spirit, with no claim of authenticity.

import CoreGraphics
import SpriteKit

// MARK: - RSRegion

/// The three circuit regions, matching the `region` ids in taverns.json
/// (`sumer`, `egypt`, `mexica`).
public enum RSRegion: String, CaseIterable, Sendable, Codable {
    case sumer
    case egypt
    case mexica

    /// Create from a content region id (taverns.json). Unknown ids fall
    /// back to the Ur theme, the game's home region.
    public init(contentID: String) {
        self = RSRegion(rawValue: contentID) ?? .sumer
    }

    /// Display name for UI (e.g. "Ur", "Thebes", "Tenochtitlan").
    public var displayName: String {
        switch self {
        case .sumer: return "Ur"
        case .egypt: return "Thebes"
        case .mexica: return "Tenochtitlan"
        }
    }
}

// MARK: - BoardMotif

/// The decorative border motif for a region's board (RS-P6.1). All motifs
/// are purely geometric — RESEARCH.md §1 forbids fake cuneiform or other
/// invented script.
public enum BoardMotif: Sendable, Equatable {
    /// Ur: small gold diamond chips set into the inlay border.
    case diamondChips
    /// Thebes: a step-fret (meander) tick row along the border.
    case stepFret
    /// Tenochtitlan: a diamond lattice of jade and turquoise chips.
    case diamondLattice
}

// MARK: - RegionTheme

/// A procedural art theme for one region (RS-P6.1). Every color is a
/// reconstruction-inspired value; the Ur palette is pinned to RESEARCH.md
/// §1. The theme is the single source of truth for board and tavern art.
public struct RegionTheme: Sendable, Equatable {
    /// The region this theme describes.
    public let region: RSRegion
    /// Dark ground under the inlay (bitumen bedding / obsidian).
    public let bedding: SKColor
    /// Worn wood frame around the board.
    public let frame: SKColor
    /// Shell inlay base for track squares.
    public let squareShell: SKColor
    /// Alternate square tone (aged inlay).
    public let squareAlt: SKColor
    /// Lapis / turquoise inlay for rosette squares and the player-0 pieces.
    public let lapis: SKColor
    /// Gold highlights: rosette centers, strokes, the dice display.
    public let gold: SKColor
    /// Region accent (red limestone / red ochre / cinnabar).
    public let accent: SKColor
    /// The decorative border motif.
    public let motif: BoardMotif
    /// Tavern wall color.
    public let tavernWall: SKColor
    /// Tavern beams and shelf silhouettes.
    public let tavernBeam: SKColor
    /// Lantern glow color.
    public let tavernGlow: SKColor

    /// Build the theme for a region.
    public init(region: RSRegion) {
        switch region {
        case .sumer:
            // Ur: RESEARCH.md §1 palette.
            self.region = .sumer
            self.bedding = SKColor.rsColor(hex: 0x2B2620)  // bitumen
            self.frame = SKColor.rsColor(hex: 0x5C4426)  // worn wood
            self.squareShell = SKColor.rsColor(hex: 0xEFE6D2)  // shell
            self.squareAlt = SKColor.rsColor(hex: 0xE3D6BC)  // aged shell
            self.lapis = SKColor.rsColor(hex: 0x26428B)  // lapis
            self.gold = SKColor.rsColor(hex: 0xC9A44C)  // gold
            self.accent = SKColor.rsColor(hex: 0xA0422D)  // red limestone
            self.motif = .diamondChips
            self.tavernWall = SKColor.rsColor(hex: 0x4A3A28)
            self.tavernBeam = SKColor.rsColor(hex: 0x3A2C1E)
            self.tavernGlow = SKColor.rsColor(hex: 0xC9A44C)
        case .egypt:
            // Thebes: reconstruction-inspired (ADR-0013).
            self.region = .egypt
            self.bedding = SKColor.rsColor(hex: 0x2B2620)
            self.frame = SKColor.rsColor(hex: 0x7A5C33)  // worn papyrus wood
            self.squareShell = SKColor.rsColor(hex: 0xE8D5A3)  // papyrus
            self.squareAlt = SKColor.rsColor(hex: 0xD9CBA8)  // limestone
            self.lapis = SKColor.rsColor(hex: 0x3E8E8C)  // turquoise
            self.gold = SKColor.rsColor(hex: 0xC9A44C)
            self.accent = SKColor.rsColor(hex: 0xA0422D)  // red ochre
            self.motif = .stepFret
            self.tavernWall = SKColor.rsColor(hex: 0x8A6B3F)
            self.tavernBeam = SKColor.rsColor(hex: 0x5C4426)
            self.tavernGlow = SKColor.rsColor(hex: 0xE8C86B)
        case .mexica:
            // Tenochtitlan: reconstruction-inspired (ADR-0013).
            self.region = .mexica
            self.bedding = SKColor.rsColor(hex: 0x2B2620)  // obsidian
            self.frame = SKColor.rsColor(hex: 0x4A3A28)
            self.squareShell = SKColor.rsColor(hex: 0xEFE6D2)  // shell white
            self.squareAlt = SKColor.rsColor(hex: 0xD9CBA8)
            self.lapis = SKColor.rsColor(hex: 0x3E8E8C)  // turquoise
            self.gold = SKColor.rsColor(hex: 0xC9A44C)  // maize
            self.accent = SKColor.rsColor(hex: 0x8C3B2E)  // cinnabar
            self.motif = .diamondLattice
            self.tavernWall = SKColor.rsColor(hex: 0x3E3226)
            self.tavernBeam = SKColor.rsColor(hex: 0x2B2620)
            self.tavernGlow = SKColor.rsColor(hex: 0xC9A44C)
        }
    }
}

// MARK: - SKColor hex helper

extension SKColor {
    /// Create an opaque color from a 0xRRGGBB hex value.
    public static func rsColor(hex: UInt32) -> SKColor {
        SKColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0)
    }

    /// sRGB components of this color, each in 0–1.
    private static func sRGBA(
        _ color: SKColor
    ) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        #if os(macOS)
            let ns = color.usingColorSpace(.sRGB)
            r = ns?.redComponent ?? 0
            g = ns?.greenComponent ?? 0
            b = ns?.blueComponent ?? 0
            a = ns?.alphaComponent ?? 0
        #else
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (r, g, b, a)
    }

    /// A copy of this color with a different alpha.
    public func withAlpha(_ alpha: CGFloat) -> SKColor {
        let (r, g, b, _) = SKColor.sRGBA(self)
        return SKColor(red: r, green: g, blue: b, alpha: alpha)
    }

    /// The sRGB components of this color as a 0xRRGGBB hex value, used by
    /// tests to pin palettes to RESEARCH.md's documented values.
    public static func hex(_ color: SKColor) -> UInt32 {
        let (r, g, b, _) = SKColor.sRGBA(color)
        func byte(_ v: CGFloat) -> UInt32 {
            let clamped = max(0, min(1, v))
            return UInt32((clamped * 255.0).rounded())
        }
        return (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }
}
