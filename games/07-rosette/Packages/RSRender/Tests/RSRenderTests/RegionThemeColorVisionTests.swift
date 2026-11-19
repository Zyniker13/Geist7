// RSRender — color-vision-deficiency checks for the region themes (RS-P8).

import RSCore
import SpriteKit
import XCTest

@testable import RSRender

/// Simulates the Machado, Oliveira & Fernandes (2009) color-vision-
/// deficiency severity-1.0 transforms on sRGB triples and checks the
/// region palettes still separate players. Shapes are the primary
/// identifier (RS-P8.1: circle versus diamond); these checks pin color
/// and luminance as the supplementary signals.
final class RegionThemeColorVisionTests: XCTestCase {
    /// Machado et al. (2009) deuteranopia simulation matrix, severity 1.0
    /// (rows transform the linear input RGB; applied here directly to
    /// sRGB values, the common approximation for screen colors).
    private static let deuteranopia: [[Double]] = [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501, 0.047413],
        [-0.011820, 0.042940, 0.968881],
    ]

    /// Machado et al. (2009) protanopia matrix, severity 1.0.
    private static let protanopia: [[Double]] = [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ]

    /// Machado et al. (2009) tritanopia matrix, severity 1.0.
    private static let tritanopia: [[Double]] = [
        [1.255528, -0.076749, -0.178779],
        [-0.078411, 0.930809, 0.147602],
        [0.004733, 0.691367, 0.303900],
    ]

    /// All simulated vision variants the checks run under.
    private static let simulations: [(String, [[Double]])] = [
        ("deuteranopia", deuteranopia),
        ("protanopia", protanopia),
        ("tritanopia", tritanopia),
    ]

    private static let regions: [RSRegion] = [.sumer, .egypt, .mexica]

    // MARK: Color math

    /// The sRGB triple (0...1) of a theme color.
    private func rgb(_ color: SKColor) -> SIMD3<Double> {
        let hex = SKColor.hex(color)
        return SIMD3(
            Double((hex >> 16) & 0xFF) / 255.0,
            Double((hex >> 8) & 0xFF) / 255.0,
            Double(hex & 0xFF) / 255.0)
    }

    /// A simulated color for the given deficiency matrix.
    private func simulate(_ color: SIMD3<Double>, matrix: [[Double]]) -> SIMD3<Double> {
        var out = SIMD3<Double>.zero
        for row in 0..<3 {
            out[row] = max(0, min(1, matrix[row][0] * color.x + matrix[row][1] * color.y + matrix[row][2] * color.z))
        }
        return out
    }

    /// The WCAG relative luminance of an sRGB triple.
    private func luminance(_ color: SIMD3<Double>) -> Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = linearize(color.x)
        let g = linearize(color.y)
        let b = linearize(color.z)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// The WCAG contrast ratio between two sRGB triples (1...21).
    private func contrast(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The composited fill of a regular square: square shell at the
    /// scene's 0.85 alpha over the board bedding.
    private func compositedSquare(_ theme: RegionTheme) -> SIMD3<Double> {
        let shell = rgb(theme.squareShell)
        let bedding = rgb(theme.bedding)
        return shell * 0.85 + bedding * 0.15
    }

    // MARK: Checks

    func testPlayerFillsRemainDistinguishableUnderColorBlindness() {
        for region in Self.regions {
            let theme = RegionTheme(region: region)
            let player0 = rgb(theme.lapis)
            let player1 = rgb(theme.squareShell)
            for (name, matrix) in Self.simulations {
                let p0 = simulate(player0, matrix: matrix)
                let p1 = simulate(player1, matrix: matrix)
                let ratio = contrast(p0, p1)
                XCTAssertGreaterThanOrEqual(
                    ratio, 2.4,
                    "\(region.rawValue): player fills merge under \(name) (contrast \(String(format: "%.2f", ratio)))")
                if region == .sumer {
                    // The default theme is the strictest: WCAG-level 3:1.
                    XCTAssertGreaterThanOrEqual(
                        ratio, 3.0,
                        "\(region.rawValue): default theme below 3:1 under \(name) (contrast \(String(format: "%.2f", ratio)))")
                }
            }
        }
    }

    func testPieceLuminanceOrderingHoldsUnderColorBlindness() {
        for region in Self.regions {
            let theme = RegionTheme(region: region)
            let player0 = rgb(theme.lapis)
            let player1 = rgb(theme.squareShell)
            let square = compositedSquare(theme)
            for (name, matrix) in Self.simulations {
                let s0 = simulate(player0, matrix: matrix)
                let s1 = simulate(player1, matrix: matrix)
                let sSquare = simulate(square, matrix: matrix)
                XCTAssertLessThan(
                    luminance(s0), luminance(sSquare),
                    "\(region.rawValue): player-0 fill must stay darker than the square under \(name)")
                XCTAssertGreaterThan(
                    luminance(s1), luminance(sSquare),
                    "\(region.rawValue): player-1 fill must stay lighter than the square under \(name)")
            }
        }
    }

    func testGoldStrokesStayVisibleOnBothPieceColors() {
        for region in Self.regions {
            let theme = RegionTheme(region: region)
            let player0 = rgb(theme.lapis)
            let player1 = rgb(theme.squareShell)
            let gold = rgb(theme.gold)
            for (name, matrix) in Self.simulations {
                let g = simulate(gold, matrix: matrix)
                let strokeOnP0 = contrast(g, simulate(player0, matrix: matrix))
                let strokeOnP1 = contrast(g, simulate(player1, matrix: matrix))
                XCTAssertGreaterThanOrEqual(
                    strokeOnP0, 1.3,
                    "\(region.rawValue): gold stroke invisible on player 0 under \(name) (contrast \(String(format: "%.2f", strokeOnP0)))")
                XCTAssertGreaterThanOrEqual(
                    strokeOnP1, 1.3,
                    "\(region.rawValue): gold stroke invisible on player 1 under \(name) (contrast \(String(format: "%.2f", strokeOnP1)))")
            }
        }
    }

    func testUnsimulatedPalettesMeetThreeToOne() {
        // Sanity anchor for the simulation itself: with no deficiency the
        // default theme must clear the WCAG 3:1 graphics threshold.
        let theme = RegionTheme(region: .sumer)
        let ratio = contrast(rgb(theme.lapis), rgb(theme.squareShell))
        XCTAssertGreaterThanOrEqual(ratio, 3.0)
    }
}
