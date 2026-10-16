import SwiftUI
import UIKit

/// Course artwork is kept separate from user-created deck images.
/// The bundled 1 x 1 PNG files reserve filenames until real artwork is supplied.
enum CourseVocabularyImages {
    static func image(named name: String) -> UIImage? {
        guard let resource = resourceName(from: name) else { return nil }

        // Xcode may preserve the folder or flatten its files into the bundle.
        for fileExtension in resource.extensions {
            for subdirectory in ["koreanimages", nil] as [String?] {
                if let url = Bundle.main.url(
                    forResource: resource.stem,
                    withExtension: fileExtension,
                    subdirectory: subdirectory
                ), let image = UIImage(contentsOfFile: url.path), isUsable(image) {
                    return image
                }
            }
        }

        // Also allow the same names to be provided by an asset catalog later.
        for assetName in ["koreanimages/\(resource.stem)", resource.stem] {
            if let image = UIImage(named: assetName), isUsable(image) {
                return image
            }
        }
        return nil
    }

    private static func resourceName(from name: String) -> (stem: String, extensions: [String])? {
        var filename = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if filename.hasPrefix("koreanimages/") {
            filename.removeFirst("koreanimages/".count)
        }
        guard !filename.isEmpty,
              !filename.hasPrefix("."),
              !filename.contains("/"),
              !filename.contains("\\") else { return nil }

        let fileExtension = (filename as NSString).pathExtension.lowercased()
        let stem = fileExtension.isEmpty ? filename : (filename as NSString).deletingPathExtension
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !stem.isEmpty,
              stem.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else { return nil }

        let supportedExtensions = ["png", "jpg", "jpeg"]
        guard fileExtension.isEmpty || supportedExtensions.contains(fileExtension) else { return nil }
        return (stem, fileExtension.isEmpty ? supportedExtensions : [fileExtension])
    }

    private static func isUsable(_ image: UIImage) -> Bool {
        if let pixels = image.cgImage {
            return pixels.width > 1 || pixels.height > 1
        }
        return image.size.width * image.scale > 1 || image.size.height * image.scale > 1
    }
}

struct CourseVocabularyImage: View {
    let name: String
    let label: String
    var compact: Bool = false

    var body: some View {
        let artwork = CourseVocabularyImages.image(named: name)
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous)
                .fill(Color.primary.opacity(0.035))

            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .padding(compact ? 8 : 14)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: compact ? 25 : 38, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.55))
                    .frame(width: compact ? 52 : 76, height: compact ? 52 : 76)
                    .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: compact ? 12 : 18))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 96 : 164)
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(artwork == nil ? "Image placeholder for \(label)" : "Image of \(label)")
        .accessibilityAddTraits(.isImage)
    }
}
