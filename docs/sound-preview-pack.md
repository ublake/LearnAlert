# LearnAlert original sound pack

Created November 1, 2026. Fifty original, short procedural sound designs:

| Group | Count | Intended use |
| --- | ---: | --- |
| App effects | 30 | Answers, cards, matching, hints, decks, likes, profiles, importing, streaks and completion |
| Ringtones | 10 | Short notification-tone options |
| Schedule celebrations | 10 | A lift, musical bloom and gentle firework sparkles for successful scheduling |

The pack is a **preview collection**. The gallery in Settings plays these files
on request; it does not replace existing sounds or activate new sound events.
Event names in the manifest are suggestions for future integration.

## Audio assets

`LearnAlert/Sounds/PreviewPack/` contains exactly 50 WAV files and
`learnalert-sound-pack.json`. Each WAV uses 44,100 Hz, mono, signed 16-bit
little-endian PCM. Clips range from 0.26 to 3.20 seconds; the complete pack
contains 75.89 seconds of audio and approximately 6.7 MB of uncompressed WAVs.
Every ringtone is shorter than Apple's 30-second notification-sound limit.

The original sound family uses glass and bell synthesis, rounded digital tones,
wood and marimba-like resonances, soft plucked harmonics, filtered breath and
small sparkling particles. Incorrect answers use a gentle low descending cue.
The schedule variations use distinct motifs and timbres with quiet, synthesized
firework fizz rather than an abrupt explosion.

No downloaded audio, third-party samples, speech, copyrighted melodies or
external sound-generation services were used. These sounds were composed and
synthesized specifically for LearnAlert. The generated assets and source can
be used, edited and distributed as part of LearnAlert.

## Rebuilding

Use Python 3.10 or newer; there are no third-party Python dependencies:

```sh
python3 scripts/generate_preview_sound_pack.py
```

This overwrites only the named pack assets and manifest, and writes a playable
HTML index and a spaced 50-sound sampler to the sibling folder
`../LearnAlert-Sound-Preview/`. That preview folder is outside the app and Git
checkout. Use `--no-preview` to skip those extra deliverables.

Each recipe is authored separately. Fixed random seeds only control small
timbre details, air and sparkles. The output is deterministic for a given
Python/math implementation. Whole-file edge fades, note envelopes and quiet
filtered reflections prevent hard cuts. Layered peaks use soft saturation;
normalization aims for -21 dBFS active-sample RMS with a -4 dBFS peak ceiling.
This active RMS target is not an integrated LUFS claim.

## Manifest contract

The JSON has `version`, `sampleRate`, `channels`, `bitsPerSample`, `created`,
`license`, `previewOnly` and `sounds` at its root. Each sound has:

```json
{
  "id": "ui.correct_bloom",
  "title": "Correct · Bloom",
  "category": "interface",
  "event": "answer.correct",
  "fileName": "la_ui_correct_bloom.wav",
  "description": "A round ascending glass answer chime.",
  "duration": 0.64,
  "peakDBFS": -9.0,
  "rmsDBFS": -24.0
}
```

The example measurements are illustrative; use the actual per-file values in
the generated manifest. Categories are `interface`, `ringtone` and
`celebration`. IDs and WAV basenames are stable. The main app's synchronized
Xcode source group includes these resources automatically; the extension does
not need this preview pack. Look up a WAV by its unique `la_` basename, with a
`Sounds/PreviewPack` subdirectory fallback if resource packaging changes.

## Validation

The delivered files were read back as PCM WAVs and checked for count, unique
content hashes, sample rate/channels/sample width, durations, nonzero signal,
headroom, and zero-valued first/last samples. The loudest generated peak is
below -7.5 dBFS, leaving more headroom than the -4 dBFS ceiling. The manifest
records full-file RMS and peak measurements. Numerical checks do not replace
subjective listening on the devices where the app will be used.
