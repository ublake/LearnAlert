import Foundation
import CoreGraphics

/// Pure geometry shared with the extension; iOS still owns notification width and final size.
nonisolated enum NotificationViewportGeometry {
    static func containerHeight(sceneHeight: CGFloat?, displayHeight: CGFloat) -> CGFloat {
        // The extension's scene can be the bubble itself, including after expansion.
        // Feeding that height back into the budget repeatedly shrinks and expands it.
        // Use the screen belonging to this scene; UIKit still caps the final bubble.
        if displayHeight.isFinite && displayHeight > 0 { return displayHeight }
        if let sceneHeight, sceneHeight.isFinite, sceneHeight > 0 { return sceneHeight }
        return 760
    }
    static func maximumHeight(containerHeight: CGFloat) -> CGFloat {
        let height = containerHeight.isFinite && containerHeight > 0 ? containerHeight : 760
        return min(height, max(160, min(680, height - 220)))
    }
    /// Leave room for system notification chrome while using more of the
    /// display for imported HTML. UIKit may grant less; the view fits that size.
    static func ankiPreferredHeight(containerHeight: CGFloat) -> CGFloat {
        let height = containerHeight.isFinite && containerHeight > 0 ? containerHeight : 760
        return min(height, max(160, min(760, height - 200)))
    }
    /// The preferred extent comes from intrinsic content and chrome, never the
    /// viewport UIKit granted in response to a previous sizing request.
    static func ankiPreferredHeight(contentHeight: CGFloat, containerHeight: CGFloat, baseline: CGFloat = 240) -> CGFloat {
        let maximum = ankiPreferredHeight(containerHeight: containerHeight)
        let floor = baseline.isFinite && baseline > 0 ? baseline : 240
        let content = contentHeight.isFinite && contentHeight > 0 ? ceil(contentHeight) : floor
        return min(maximum, max(min(floor, maximum), content))
    }
    /// Render inside the granted viewport, allowing long HTML to scroll while
    /// leaving its header and review controls outside the card.
    static func ankiCardHeight(contentHeight: CGFloat?, viewportHeight: CGFloat, chromeHeight: CGFloat,
                               minimum: CGFloat = 100, fallback: CGFloat = 160) -> CGFloat {
        let viewport = viewportHeight.isFinite && viewportHeight > 0 ? viewportHeight : 0
        let chrome = chromeHeight.isFinite && chromeHeight > 0 ? chromeHeight : 0
        let floor = minimum.isFinite && minimum > 0 ? minimum : 100
        let estimate = fallback.isFinite && fallback > 0 ? fallback : 160
        let content = contentHeight.flatMap { $0.isFinite && $0 > 0 ? ceil($0) : nil } ?? estimate
        // A system-granted viewport smaller than the floor still wins.
        return min(max(0, viewport - chrome), max(floor, content))
    }
    static func preferredHeight(contentHeight: CGFloat, containerHeight: CGFloat, baseline: CGFloat = 300) -> CGFloat {
        let maximum = maximumHeight(containerHeight: containerHeight)
        let content = contentHeight.isFinite && contentHeight > 0 ? ceil(contentHeight) : baseline
        return min(maximum, max(min(baseline, maximum), content))
    }
    static func usableRect(in bounds: CGRect, avoiding regions: [CGRect]) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        var candidates = [bounds]
        for region in regions where !region.isNull && region.width > 0 && region.height > 0 {
            candidates = candidates.flatMap { rect -> [CGRect] in
                let overlap = rect.intersection(region)
                guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return [rect] }
                return [CGRect(x: rect.minX, y: rect.minY, width: overlap.minX - rect.minX, height: rect.height),
                        CGRect(x: overlap.maxX, y: rect.minY, width: rect.maxX - overlap.maxX, height: rect.height),
                        CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: overlap.minY - rect.minY),
                        CGRect(x: rect.minX, y: overlap.maxY, width: rect.width, height: rect.maxY - overlap.maxY)]
                    .filter { $0.width > 0 && $0.height > 0 }
            }
            // Keep several candidates: a later occlusion can make another region preferable.
            candidates = Array(candidates.sorted { $0.width * $0.height > $1.width * $1.height }.prefix(32))
        }
        return candidates.max { $0.width * $0.height < $1.width * $1.height } ?? .zero
    }
}
