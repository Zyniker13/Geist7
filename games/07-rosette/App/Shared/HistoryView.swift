// MARK: - HistoryView

import RSContent
import RSCore
import SwiftUI

/// The "History" panel (RS-P3.2): one page per ruleset quoting its sources,
/// with its HIST3.1 label shown throughout, plus an About card explaining
/// how the game treats history.
struct HistoryView: View {
    @State private var rulesets: [RulesetDef] = []
    @State private var loadError: String?

    var body: some View {
        Group {
            if let error = loadError {
                ContentUnavailableView(
                    "History unavailable", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            } else {
                List {
                    Section("About") {
                        aboutCard
                    }
                    Section("The Rulesets") {
                        ForEach(rulesets, id: \.id) { ruleset in
                            NavigationLink(value: ruleset.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ruleset.name)
                                        .font(.subheadline)
                                    Text(ruleset.label.displayName)
                                        .font(.caption2)
                                        .foregroundColor(labelColor(ruleset.label))
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: String.self) { id in
                    if let ruleset = rulesets.first(where: { $0.id == id }) {
                        RulesetDetail(ruleset: ruleset)
                    }
                }
            }
        }
        .navigationTitle("Rules & History")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if rulesets.isEmpty, loadError == nil {
                do {
                    rulesets = try ContentLoader().loadRulesets()
                } catch {
                    loadError = "\(error)"
                }
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What is history here?")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(
                "The Royal Game of Ur is about 4,500 years old: its boards are dated c. 2600–2400 BCE. The board, the pieces, and the dice are attested in the archaeological record. How the game was played is not fully recorded: the modern rules below are a reconstruction, and the Babylonian tablet of Itti-Marduk-balāṭu describes a later five-piece variant. Every element in this game carries its label — Attested, Reconstructed, or Invented — so you always know what the evidence supports."
            )
            .font(.caption)
            .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Label("Attested", systemImage: "checkmark.seal")
                    .foregroundColor(.green)
                Label("Reconstructed", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                Label("Invented", systemImage: "sparkles")
                    .foregroundColor(.orange)
            }
            .font(.caption2)
        }
        .padding(.vertical, 4)
    }

    private func labelColor(_ label: HistoryLabel) -> Color {
        switch label {
        case .attested: return .green
        case .reconstructed: return .blue
        case .invented: return .orange
        }
    }
}

/// One ruleset's history page: its parameters, label, and quoted source.
struct RulesetDetail: View {
    let ruleset: RulesetDef

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ruleset.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(ruleset.label.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(labelColor)
                        .cornerRadius(6)
                }
                .padding(.vertical, 4)
            }
            Section("How it plays") {
                row("Path length", "\(ruleset.trackLength) squares")
                row("Pieces each", "\(ruleset.pieces)")
                row(
                    "Rosette squares",
                    ruleset.rosettes.isEmpty
                        ? "None"
                        : ruleset.rosettes.map { $0 + 1 }.map(String.init).joined(separator: ", "))
                row(
                    "Rosette safety",
                    ruleset.safeRosettes.isEmpty ? "None are safe" : "The shared rosette is safe")
                row(
                    "Dice",
                    diceName)
                row(
                    "Bearing off",
                    ruleset.exactBearOff
                        ? "Exact count required" : "Any roll past the end bears off")
                row(
                    "Captures",
                    ruleset.captureRule == .standard ? "Landing on a piece sends it home" : "None")
                row(
                    "Extra roll on a rosette",
                    ruleset.extraRollOnRosette ? "Yes" : "No")
            }
            Section("Source") {
                Text("\"\(ruleset.source)\"")
                    .font(.caption)
                    .italic()
            }
        }
        .navigationTitle(ruleset.label.displayName)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var diceName: String {
        switch ruleset.dice {
        case "tetra4": return "Four tetrahedral dice (0–4 pips)"
        case "astragal4": return "Four astragals (knucklebones), uneven odds"
        case "stick4": return "Four throwing sticks"
        case "beans5": return "Five marked beans"
        default: return ruleset.dice
        }
    }

    private var labelColor: Color {
        switch ruleset.label {
        case .attested: return .green
        case .reconstructed: return .blue
        case .invented: return .orange
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
