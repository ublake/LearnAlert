# AnkiArchive

On-device APKG decoding for LearnAlert. ZIPFoundation 0.9.20 is pinned (MIT).
The app integrates the local AnkiArchive and CZstd pods through `LearnAlert.xcworkspace`.
This builds all dependencies with the app's enhanced-security settings, including
the arm64e and hardware-checked pointer-arithmetic slices required for device builds.
The Swift package remains available for standalone parser tests on macOS.
CZstd is the generated decompression-only amalgamation from Zstandard v1.5.7,
commit f8745da6ff1ad1e7bab384bd1f9d742439278e99, generated with
`build/single_file_libs/create_single_file_decoder.sh`. Its BSD license is retained here.
No Anki application code is incorporated. Package/schema interoperability is implemented
from the documented file formats and the upstream protobuf field definitions.

The reader supports legacy SQLite packages and modern Zstandard/protobuf packages.
It never imports Anki scheduling history or executes SQL supplied by a package.
Extraction has byte/count limits, cancellation, CRC validation, and safe local media names.
