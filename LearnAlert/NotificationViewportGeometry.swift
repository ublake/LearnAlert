import Foundation
import CoreGraphics

/// Pure geometry shared with the extension; iOS still owns notification width and final size.
nonisolated enum NotificationViewportGeometry {
    static func containerHeight(sceneHeight: CGFloat?, displayHeight: CGFloat) -> CGFloat {
        let display = displayHeight.isFinite && displayHeight > 0 ? displayHeight : 760
        guard let sceneHeight, sceneHeight.isFinite, sceneHeight > 0 else { return display }
        // Notification hosts can report their collapsed bubble as the scene size.
        if sceneHeight < 360 && display >= 600 { return display }
        return sceneHeight
    }
    static func maximumHeight(containerHeight: CGFloat) -> CGFloat {
        let height = containerHeight.isFinite && containerHeight > 0 ? containerHeight : 760
        return min(height, max(160, min(680, height - 220)))
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
