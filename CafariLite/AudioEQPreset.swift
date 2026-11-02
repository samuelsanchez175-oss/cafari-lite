import Foundation

/// Equalizer presets (Reels parity). Persisted in Settings; playback DSP not wired in Cafari Lite yet.
enum AudioEQPreset: String, CaseIterable, Identifiable {
    case off = "Flat / Off"
    case bassBoost = "Bass Boost"
    case vocalClarity = "Vocal Clarity"
    case carCabin = "Car Cabin Acoustic"
    case podcast = "Podcast Speech"
    case nightCompressor = "Night Drive Compressor"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .off: return "slider.horizontal.3"
        case .bassBoost: return "speaker.wave.3.fill"
        case .vocalClarity: return "waveform"
        case .carCabin: return "car.side.fill"
        case .podcast: return "mic.fill"
        case .nightCompressor: return "moon.fill"
        }
    }

    static func load() -> AudioEQPreset {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.audioEQPreset),
              let preset = AudioEQPreset(rawValue: raw) else { return .off }
        return preset
    }

    static func save(_ preset: AudioEQPreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: SettingsKeys.audioEQPreset)
    }
}

enum SettingsKeys {
    static let audioEQPreset = "cafari.audioEQPreset"
    static let spatialAudioEnabled = "cafari.spatialAudioEnabled"
    static let libraryVerboseLogging = "libraryDebugVerbose"
}
