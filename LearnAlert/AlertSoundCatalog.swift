import Foundation

/// Stable notification filenames shared by the app and notification scheduler.
nonisolated enum AlertSoundCatalog {
    static let defaultFilename = "la_ring_cloud_drops.wav"
    static let systemDefault = "Default"

    static let ringtones: [(filename: String, title: String)] = [
        ("la_ring_cloud_drops.wav", String(localized: "Cloud drops")),
        ("la_ring_woodland.wav", String(localized: "Woodland")),
        ("la_ring_little_orbit.wav", String(localized: "Little orbit")),
        ("la_ring_sunbeam.wav", String(localized: "Sunbeam")),
        ("la_ring_pebble_pool.wav", String(localized: "Pebble pool")),
        ("la_ring_morning_keys.wav", String(localized: "Morning keys")),
        ("la_ring_paper_lantern.wav", String(localized: "Paper lantern")),
        ("la_ring_blue_hour.wav", String(localized: "Blue hour")),
        ("la_ring_tiny_comet.wav", String(localized: "Tiny comet")),
        ("la_ring_pocket_garden.wav", String(localized: "Pocket garden"))
    ]

    // The old files also contain these new tones, so requests already queued by
    // iOS switch sounds without changing their dates, card selection or budget.
    private static let legacyNames = [
        "alert1.wav": "la_ring_sunbeam.wav",
        "alert2.wav": "la_ring_little_orbit.wav",
        "alert3.wav": defaultFilename,
        "alert4.wav": "la_ring_pebble_pool.wav",
        "alert5.wav": "la_ring_morning_keys.wav"
    ]

    static func resolve(_ filename: String?) -> String {
        guard let filename else { return defaultFilename }
        if filename == systemDefault { return systemDefault }
        if let replacement = legacyNames[filename] { return replacement }
        return ringtones.contains { $0.filename == filename } ? filename : defaultFilename
    }
}
