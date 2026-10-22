#!/usr/bin/env python3
"""Export the exact bundled native curriculum by executing its Swift builders.

Requires Xcode's macOS Swift toolchain. No app build, device, network access, or
package installation is involved. Set DEVELOPER_DIR to select an Xcode version.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, default=Path("/tmp/learnalert-managed-catalog-seed.json"))
args = parser.parse_args()
output = args.output.expanduser().resolve()
output.parent.mkdir(parents=True, exist_ok=True)
base = Path(__file__).resolve().parents[1] / "LearnAlert"
chunks=['import Foundation\nimport SwiftUI\nimport CoreGraphics\n']
for file in ['CourseModels.swift','CourseActivity.swift','CourseCurriculum.swift','CourseCurriculum+Korean.swift','CourseCurriculum+ExpandedKorean.swift','CourseCurriculum+Practice.swift','CourseCurriculum+FoundationWorkshop.swift']:
 s=(base/file).read_text();s='\n'.join(x for x in s.splitlines() if not x.startswith('import '));chunks.append(s)
chunks.append((base/'CourseSectionGuide.swift').read_text().split('struct CourseGuideSheet:')[0].replace('import SwiftUI',''))
chunks.append((base/'Models.swift').read_text().split('@Model')[0].replace('import SwiftData',''))
chunks.append((base/'CardFieldMedia.swift').read_text().split('enum CardChoiceIdentity')[0].replace('import SwiftUI',''))
# Use the actual portable Anki value definition; exclude only its SwiftData cleanup.
chunks.append((base/'AnkiCardContent.swift').read_text().split('nonisolated enum AnkiMediaCleanup')[0].replace('import SwiftData',''))
chunks.append((base/'ManagedCatalog.swift').read_text().split('// The manifest')[0].replace('import Foundation','').replace('import Combine',''))
chunks.append('''
// Export does not play or resolve runtime audio. Keep these service boundaries
// deterministic so schema export never initializes an audio device/synthesizer.
enum CardAudioStore { static func isAvailable(named: String?) -> Bool { false } }
final class KoreanSpeechManager {
 static let shared = KoreanSpeechManager()
 func canPlay(_ text: String) -> Bool { false }
}
struct Deck { var sourceCommunityID: String?; var sourcePremadeID: String? }
final class ManagedCatalogStore {
 static let shared = ManagedCatalogStore()
 var courses: [CourseDefinition] { CourseCurriculumCatalog.bundledCourses }
 var examDecks: [PremadeDeck] { PremadeDeckCatalog.bundledDecks.filter {$0.category == "Exam Prep"} }
 func course(for id: String) -> CourseDefinition? {courses.first{$0.id == id}}
}
struct Seed: Encodable { let schemaVersion = 1; let items: [SeedItem] }
enum SeedItem: Encodable {
 case course(CourseDefinition), exam(PremadeDeck)
 enum CodingKeys: String, CodingKey {case id, kind, document}
 func encode(to encoder: Encoder) throws {
  var c = encoder.container(keyedBy: CodingKeys.self)
  switch self {
  case .course(let course):
   try c.encode(course.id, forKey:.id);try c.encode("course",forKey:.kind);try c.encode(course,forKey:.document)
  case .exam(let deck):
   try c.encode(deck.id, forKey:.id);try c.encode("exam",forKey:.kind);try c.encode(deck,forKey:.document)
  }
 }
}
let courses = CourseCurriculumCatalog.bundledCourses.map { course in
 let guides = Dictionary(uniqueKeysWithValues: course.units.map { ($0.id, CourseSectionGuides.topics(course:course,unit:$0)) })
 let presentation = Dictionary(uniqueKeysWithValues: course.units.map {unit in
  (unit.id, course.language == "Korean" && unit.unitNumber == 1
  ? CourseGuidePresentation(showsHangulDiagram:true,referenceTitle:"More about Hangul · National Institute of Korean Language",referenceURL:"https://www.korean.go.kr/eng_hangeul/principle/001.html",diagramTitle:"How the letters fit",diagramFooter:"Initial → vowel → final (if present)",diagramExamples:CourseGuideDiagramExample.bundled)
  : CourseGuidePresentation())
 })
 return CourseDefinition(id:course.id,title:course.title,language:course.language,flagEmoji:course.flagEmoji,levelTag:course.levelTag,colorHex:course.colorHex,summary:course.summary,estimatedHours:course.estimatedHours,outcomes:course.outcomes,units:course.units,guides:guides,guidePresentation:presentation,learning:course.learning)
}
let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
let items = courses.map(SeedItem.course) + PremadeDeckCatalog.bundledDecks.filter{$0.category == "Exam Prep"}.map(SeedItem.exam)
let data = try encoder.encode(Seed(items:items))
try data.write(to:URL(fileURLWithPath:CommandLine.arguments.last!))
print("Exported \\(items.count) items: \\(courses.count) courses, \\(items.count - courses.count) exams, \\(data.count) bytes")
''')
with tempfile.TemporaryDirectory(prefix="learnalert-catalog-export-") as temporary:
    source = Path(temporary) / "main.swift"
    source.write_text("\n".join(chunks))
    subprocess.run(["xcrun", "swift", str(source), str(output)], check=True)
print(f"Saved {output}")
