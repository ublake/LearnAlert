# Korean vocabulary images

Replace these PNG files with your own pictures, keeping the filenames below. The included files are valid transparent 1 x 1 pixel placeholders. LearnAlert deliberately displays a neutral photo placeholder until a real image is available.

| Filename | Korean | Meaning |
| --- | --- | --- |
| `child.png` | 아이 | child |
| `tree.png` | 나무 | tree |
| `sea.png` | 바다 | sea |
| `milk.png` | 우유 | milk |
| `water.png` | 물 | water |
| `door.png` | 문 | door |
| `mountain.png` | 산 | mountain |
| `house.png` | 집 | house |
| `person.png` | 사람 | person |
| `hat.png` | 모자 | hat |
| `flower.png` | 꽃 | flower |

Use a clear picture of the one object or concept, preferably square and at least 512 x 512 pixels. PNG images with transparent backgrounds work well. Do not include the answer as text in the picture. Rebuild the app after replacing a file.

`CourseVocabularyImages.image(named:)` accepts `tree`, `tree.png`, or `koreanimages/tree.png`. JPG/JPEG replacements also work when the card's image name includes that extension. The loader supports resources preserved in this folder and resources flattened by Xcode. The same image resources must be included in the app and notification extension targets to appear in both places. The README is documentation and should not be copied into either target's resources.

The current image-enabled activities use only their assigned filenames; adding a file does not create a lesson or vocabulary card.
