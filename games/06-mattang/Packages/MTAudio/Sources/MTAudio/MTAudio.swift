// MTAudio — sound for Mattang.
//
// Owns: swell and strike sounds, UI feedback, and the ambient ocean
// bed. All playback is derived from engine events; audio never feeds
// back into the engine.

/// Module root. Audio content and the sound map arrive with P8; P0
/// keeps the package compiling with this placeholder.
public enum MTAudioInfo {
    /// Package identity string, for build sanity checks.
    public static let identifier = "MTAudio"
}
