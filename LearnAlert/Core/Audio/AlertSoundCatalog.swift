import Foundation

/// Stable notification filenames shared by the app and notification scheduler.
nonisolated enum AlertSoundCatalog {
    static let defaultFilename = "la_ring_tiny_comet.wav"
    static let systemDefault = "Default"

    static var ringtones: [(filename: String, title: String)] { [
        ("la_ring_cloud_drops.wav", AppLocalization.string("Drops")),
        ("la_ring_woodland.wav", AppLocalization.string("Wood")),
        ("la_ring_little_orbit.wav", AppLocalization.string("Orbit")),
        ("la_ring_sunbeam.wav", AppLocalization.string("Beam")),
        ("la_ring_pebble_pool.wav", AppLocalization.string("Pebble")),
        ("la_ring_morning_keys.wav", AppLocalization.string("Keys")),
        ("la_ring_paper_lantern.wav", AppLocalization.string("Lantern")),
        ("la_ring_blue_hour.wav", AppLocalization.string("Dusk")),
        ("la_ring_tiny_comet.wav", AppLocalization.string("Comet")),
        ("la_ring_pocket_garden.wav", AppLocalization.string("Bloom"))
    ] }

    // The old files also contain these new tones, so requests already queued by
    // iOS switch sounds without changing their dates, card selection or budget.
    private static let legacyNames = [
        "alert1.wav": "la_ring_sunbeam.wav",
        "alert2.wav": "la_ring_little_orbit.wav",
        "alert3.wav": "la_ring_cloud_drops.wav",
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
