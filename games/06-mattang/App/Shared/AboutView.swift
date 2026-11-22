import SwiftUI

/// The About the Tradition screen (MT-P3.2, SRC3.1). Renders the four
/// sourced claims (C-1..C-4, keyed in `AboutText`) plus the
/// no-teaching-navigation statement and the advisor-review placeholder.
/// Reachable from the menu; UI-tested by `testAboutOpensAndShowsClaims`.
struct AboutView: View {
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("About the Tradition")
                    .font(.title2.weight(.bold))
                Text(AboutText.advisorParagraph)
                    .font(.body)
                    .foregroundStyle(.secondary)
                claim(AboutText.chartsMemorisedOnLand, key: "C-1")
                claim(AboutText.islandsBendSwells, key: "C-2")
                claim(AboutText.chartTypes, key: "C-3")
                claim(AboutText.rulesAreInvented, key: "C-4")
                Divider()
                Text(AboutText.noTeachingNavigation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Back") { onDismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("aboutScreen")
    }

    private func claim(_ text: String, key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(text)
                .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aboutClaim_\(key)")
    }
}
