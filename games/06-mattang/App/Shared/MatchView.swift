// MatchView.swift — the match screen (MT-P2.1/MT-P2.2).
//
// The sea scene fills the screen; taps map to cells through the same
// HexLayout the scene draws with. Controls: Sail/Place/Pass/Cancel,
// the three overlays (rays, nodes, Marshallese names), restart, and
// the results overlay. The debug corner mark (SRC2.1) appears on
// this screen in DEBUG builds only.

import MTContent
import MTCore
import MTRender
import SwiftUI

struct MatchView: View {
    @StateObject private var model: MatchModel
    /// Leaving the match back to the menu.
    let onExit: () -> Void

    init(model: MatchModel, onExit: @escaping () -> Void) {
        _model = StateObject(wrappedValue: model)
        self.onExit = onExit
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                SeaSceneView(model: sceneModel, palette: SeaPalette.scheme(false))
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .gesture(tapGesture(size: size))
                VStack {
                    Spacer()
                    controls
                        .padding(.bottom, 12)
                }
                if model.isOver {
                    resultsOverlay
                }
                if model.isPaused {
                    pauseOverlay
                }
                if model.debugVisible {
                    VStack {
                        HStack {
                            DebugOverlay(
                                seed: model.seed, tick: model.plies,
                                hashTextOverride: model.stateHash)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                // SRC2.1: every swell name and the canoe art are still
                // pending advisor review, so DEBUG builds carry a corner
                // mark on the match screen. Release builds compile it
                // out (debugVisible is #if DEBUG), so players never see
                // it. The debug/release UI tests pin both sides.
                if model.debugVisible {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Pending advisor review")
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.yellow.opacity(0.85), in: Capsule())
                                .foregroundStyle(.black)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }
            }
        }
        .background(SeaPalette.scheme(false).deepSea.ignoresSafeArea())
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Menu") { onExit() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    viewMenu
                }
            }
        #else
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Menu") { onExit() }
                }
                ToolbarItem(placement: .primaryAction) {
                    viewMenu
                }
            }
        #endif
    }

    private var viewMenu: some View {
        Menu("View") {
            Toggle("Rays", isOn: $model.showRays)
            Toggle("Node rings", isOn: $model.showNodes)
            Toggle("Marshallese names", isOn: $model.marshalleseNames)
            Button("Restart match") { model.restart() }
        }
    }

    // MARK: Scene and hit-testing

    private var sceneModel: SeaSceneModel {
        SeaSceneModel(
            chart: model.state.chart, state: model.state,
            showRays: model.showRays, showNodes: model.showNodes,
            pathHighlight: model.pendingPath, ghostIsland: model.ghostIsland)
    }

    private func tapGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let layout = HexLayout.fitting(radius: model.state.chart.radius, in: size)
                let point = value.location
                let relative = CGPoint(
                    x: point.x - layout.center.x, y: point.y - layout.center.y)
                let cell = layout.cell(near: relative)
                if model.state.chart.ocean.contains(cell) {
                    model.tap(cell)
                } else {
                    model.cancelSelection()
                }
            }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Text(model.statusLine)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(spacing: 12) {
                Button("Sail") { model.commitSail() }
                    .disabled(!model.canSail)
                Button("Place") {
                    if let ghost = model.ghostIsland { model.tap(ghost) }
                }
                .disabled(!model.canPlace)
                Button("Pass") { model.pass() }
                    .disabled(!model.canPass)
                Button("Cancel") { model.cancelSelection() }
                    .disabled(model.selected == nil && model.ghostIsland == nil)
                Button(model.isPaused ? "Resume" : "Pause") {
                    model.togglePause()
                }
                .disabled(model.isOver)
            }
            .buttonStyle(.borderedProminent)
            .font(.subheadline)
            legend
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(SwellOrder.all, id: \.self) { id in
                Text(model.swellName(id))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var resultsOverlay: some View {
        VStack(spacing: 12) {
            Text(model.statusLine)
                .font(.largeTitle.weight(.bold))
            Button("Play again") { model.restart() }
            Button("Menu") { onExit() }
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// S2.2 pause: a small overlay so the frozen state is visible; the
    /// board stays readable underneath for studying the swell field.
    private var pauseOverlay: some View {
        VStack(spacing: 10) {
            Text("Paused")
                .font(.title2.weight(.semibold))
            Button("Resume") { model.togglePause() }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(true)
    }
}

/// The slice's swell ids in display order (east, northwest, west,
/// southeast — the glossary's entry order).
enum SwellOrder {
    static let all = ["east_dom", "north_dom", "west_min", "south_min"]
}

extension MatchModel {
    /// SRC2.1: the debug corner mark shows on the match screen in
    /// DEBUG builds; the snapshot test and the release capture pin
    /// both sides of that rule.
    var debugVisible: Bool {
        #if DEBUG
            true
        #else
            false
        #endif
    }

    /// The stable state hash for the debug overlay.
    var stateHash: String {
        (try? StateHashing.stableHash(state)).map { String(format: "0x%016llX", $0) }
            ?? "unavailable"
    }
}
