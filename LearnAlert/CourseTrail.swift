import SwiftUI

/// Home follows the bundle's ordinary SwiftData cards, rather than the retired
/// lesson/checkpoint route. Skipping a level never marks that level mastered.
struct BundleLevelTrailProjection: Equatable {
    struct Node: Identifiable, Equatable {
        let id: String
        let number: Int
        let title: String
        let learnedCount: Int
        let cardCount: Int
        let isCurrent: Bool

        var isMastered: Bool { cardCount > 0 && learnedCount == cardCount }
        var fraction: Double { Double(learnedCount) / Double(max(1, cardCount)) }
    }

    let nodes: [Node]
    var current: Node? { nodes.first(where: \.isCurrent) }
    private var windowStart: Int {
        let currentIndex = nodes.firstIndex(where: \.isCurrent) ?? 0
        return max(0, min(currentIndex - 2, nodes.count - 5))
    }
    var visibleNodes: [Node] { Array(nodes.dropFirst(windowStart).prefix(5)) }
    var hasEarlierLevels: Bool { windowStart > 0 }
    var hasLaterLevels: Bool { windowStart + visibleNodes.count < nodes.count }

    @MainActor
    init(course: CourseDefinition, bundle: Deck?) {
        let definitions = LanguageDeckProjection.levels(course)
        let sections = bundle.map(LanguageBundleStudy.levels) ?? []
        let sectionsByID = Dictionary(sections.compactMap { section in
            section.sourceCourseUnitID.map { ($0, section) }
        }, uniquingKeysWith: { first, _ in first })
        let savedCurrentID = bundle.flatMap { LanguageBundleStudy.activeLevel($0)?.sourceCourseUnitID }
        let currentID = definitions.first(where: { $0.id == savedCurrentID })?.id ?? definitions.first?.id
        nodes = definitions.enumerated().map { index, definition in
            let cards = sectionsByID[definition.id]?.cards ?? []
            return Node(id: definition.id, number: index + 1, title: definition.title,
                learnedCount: cards.filter { $0.masteryScore >= 3 }.count,
                cardCount: cards.isEmpty ? definition.cards.count : cards.count,
                isCurrent: definition.id == currentID)
        }
    }
}

/// A compact, numbered window into the bundle. The whole strip opens its
/// overview; individual dots do not alter the learner's scheduling level.
struct BundleLevelMiniTrail: View {
    let projection: BundleLevelTrailProjection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { LearnAlertStyle.appAccentForeground }
    private var masteredColor: Color { Color(hex: colorScheme == .dark ? "#89C7B6" : "#377F76") }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 0) {
                if projection.hasEarlierLevels { continuationMark }
                ForEach(Array(projection.visibleNodes.enumerated()), id: \.element.id) { index, node in
                    if index > 0 {
                        Capsule()
                            .fill(projection.visibleNodes[index - 1].isMastered && node.isMastered ? masteredColor.opacity(0.55) : LearnAlertStyle.hairline)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                    }
                    levelNode(node)
                }
                if projection.hasLaterLevels { continuationMark }
                if projection.visibleNodes.count == 1 { Spacer(minLength: 0) }
            }
            .frame(height: 34)

            if let current = projection.current {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(current.number) · \(current.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(current.learnedCount)/\(current.cardCount)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                        .fixedSize()
                }
            }
        }
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: projection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bundle level progress")
        .accessibilityValue(accessibilityProgress)
    }

    private var continuationMark: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(LearnAlertStyle.textSecondary.opacity(0.6))
            .frame(width: 22)
    }

    private func levelNode(_ node: BundleLevelTrailProjection.Node) -> some View {
        let tint = node.isMastered ? masteredColor : accent
        return ZStack {
            Circle().fill(LearnAlertStyle.surface)
            Circle().fill(node.isCurrent ? tint.opacity(0.16) : node.isMastered ? tint.opacity(0.10) : LearnAlertStyle.textSecondary.opacity(0.045))
            Circle().strokeBorder(node.isCurrent || node.isMastered ? tint.opacity(0.65) : LearnAlertStyle.hairline, lineWidth: node.isCurrent ? 1.5 : 1)
            if node.isCurrent && node.fraction > 0 && !node.isMastered {
                Circle().inset(by: 1).trim(from: 0, to: node.fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if node.isMastered {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
            } else {
                Text("\(node.number)")
                    .font(.system(size: node.isCurrent ? 13 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(node.isCurrent ? accent : LearnAlertStyle.textSecondary.opacity(0.75))
            }
        }
        .frame(width: node.isCurrent ? 32 : 26, height: node.isCurrent ? 32 : 26)
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private var accessibilityProgress: String {
        guard let current = projection.current else { return "No levels yet" }
        let mastered = projection.nodes.filter(\.isMastered).count
        return "Level \(current.number) of \(projection.nodes.count), \(current.title). \(current.learnedCount) of \(current.cardCount) cards learned. \(mastered) levels learned."
    }
}

struct CourseTrailMilestone: Identifiable, Equatable {
    let id: String
    let unitId: String
    let title: String
    let icon: String
    let status: LessonStatus
    let fraction: Double
    let isCheckpoint: Bool
    var assessmentAccess = false
    var isCurrent: Bool { !assessmentAccess && (status == .current || status == .available || status == .reviewDue) }
    var needsReview: Bool { status == .reviewDue }
    var percentage: String { "\(Int(min(1, max(0, fraction)) * 100))%" }
    var showsProgress: Bool { isCurrent && !isCheckpoint && (fraction > 0 || needsReview) }
    var symbol: String {
        status == .completed ? "checkmark" : assessmentAccess ? "arrow.forward" : status == .locked ? "lock.fill" : needsReview ? "arrow.clockwise" : icon
    }
    func tint(_ courseColor: Color) -> Color {
        needsReview ? .yellow : status == .completed ? .green : courseColor
    }
    var detail: String {
        if status == .completed { return isCheckpoint ? "Passed" : "Complete" }
        if assessmentAccess { return "Access from starter check" }
        if status == .locked { return "Locked" }
        if needsReview { return "Needs review" }
        if isCheckpoint { return "Ready for your quiz" }
        return fraction > 0 ? "In progress" : "Ready to begin"
    }
}

struct CourseTrailProjection: Equatable {
    let milestones: [CourseTrailMilestone]
    private let preferredFocusID: String?
    private let routeFallbackID: String?
    private let routeProgressIDs: Set<String>?
    var progressMilestones: [CourseTrailMilestone] { milestones.filter { routeProgressIDs?.contains($0.id) ?? true } }
    var focus: CourseTrailMilestone? {
        if let preferred = milestones.first(where: { $0.id == preferredFocusID }) { return preferred }
        if routeProgressIDs != nil { return milestones.first(where: { $0.id == routeFallbackID }) }
        return milestones.first(where: \.isCurrent) ?? milestones.last
    }
    var currentUnit: [CourseTrailMilestone] { milestones.filter { $0.unitId == focus?.unitId } }

    init(course: CourseDefinition, snapshot: CourseLearningSnapshot) {
        preferredFocusID = snapshot.currentLesson(course: course)?.id ?? snapshot.pendingCheckpoint(course: course)?.checkpointQuiz?.id
        let routeIDs = snapshot.routes[course.id]?.lessonIDs
        routeFallbackID = routeIDs?.last(where: { id in course.units.flatMap(\.lessons).contains { $0.id == id } })
        routeProgressIDs = routeIDs.map { ids in Set(ids).union(course.units.filter { unit in unit.lessons.contains { ids.contains($0.id) } }.compactMap { $0.checkpointQuiz?.id }) }
        milestones = course.units.flatMap { unit in
            var nodes = unit.lessons.map { lesson in
                let status = snapshot.status(course: course, lessonId: lesson.id)
                let learned = Set(snapshot.progress[course.id]?[lesson.id]?.masteredCardIds ?? [])
                    .intersection(Set(lesson.cards.map(\.id)))
                let needsReview = status != .locked && status != .completed && !lesson.cards.isEmpty && lesson.cards.allSatisfy {
                    learned.contains($0.id) || (snapshot.srsRecord(courseId: course.id, cardId: $0.id)?.reviewCount ?? 0) > 0
                }
                return CourseTrailMilestone(id: lesson.id, unitId: unit.id, title: lesson.title,
                    icon: lesson.nodeType.icon, status: needsReview ? .reviewDue : status,
                    fraction: status == .completed ? 1 : Double(learned.count) / Double(max(1, lesson.cards.count)), isCheckpoint: false, assessmentAccess: snapshot.assessmentAccess[course.id]?.contains(lesson.id) == true && status != .completed)
            }
            if let quiz = unit.checkpointQuiz {
                let passed = snapshot.checkpoints[course.id]?[unit.id]?.passed == true
                let ready = unit.lessons.allSatisfy { snapshot.status(course: course, lessonId: $0.id) == .completed }
                let needsReview = ready && snapshot.checkpoints[course.id]?[unit.id]?.passed == false
                nodes.append(CourseTrailMilestone(id: quiz.id, unitId: unit.id, title: "Checkpoint",
                    icon: "checkmark.shield.fill", status: passed ? .completed : needsReview ? .reviewDue : ready ? .available : .locked,
                    fraction: passed ? 1 : 0, isCheckpoint: true))
            }
            return nodes
        }
    }
}

private struct CourseTrailAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Anchor-based connections follow the actual circles at every text size.
struct CourseConnectedTrail: View {
    let milestones: [CourseTrailMilestone]
    let color: Color
    let select: (CourseTrailMilestone) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                CourseTrailNode(milestone: milestone, color: color, offset: [CGFloat(0), 18, 0, -10][index % 4]) {
                    select(milestone)
                }.id(milestone.id)
            }
        }
        .backgroundPreferenceValue(CourseTrailAnchors.self) { anchors in
            GeometryReader { proxy in
                let points = milestones.compactMap { node -> CGPoint? in
                    guard let anchor = anchors[node.id] else { return nil }
                    let rect = proxy[anchor]
                    return CGPoint(x: rect.midX, y: rect.midY)
                }
                if points.count == milestones.count {
                    ForEach(0..<max(0, points.count - 1), id: \.self) { index in
                        let path = connection(from: points[index], to: points[index + 1])
                        path.stroke(Color.primary.opacity(0.09), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        path.trimmedPath(from: 0, to: connectorFraction(milestones[index]))
                            .stroke(milestones[index].tint(color).opacity(0.75), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85), value: milestones)
    }

    private func connectorFraction(_ node: CourseTrailMilestone) -> CGFloat {
        node.status == .completed ? 1 : node.isCurrent ? CGFloat(node.fraction) : 0
    }
    private func connection(from start: CGPoint, to end: CGPoint) -> Path {
        Path { path in
            let start = CGPoint(x: start.x, y: start.y + 34)
            let end = CGPoint(x: end.x, y: end.y - 34)
            path.move(to: start)
            let middle = (start.y + end.y) / 2
            path.addCurve(to: end, control1: CGPoint(x: start.x, y: middle), control2: CGPoint(x: end.x, y: middle))
        }
    }
}

private struct CourseTrailNode: View {
    let milestone: CourseTrailMilestone
    let color: Color
    let offset: CGFloat
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    private var tint: Color { milestone.tint(color) }
    private var labelColor: Color { milestone.needsReview ? Color(.label) : color }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color(.secondarySystemGroupedBackground))
                    Circle().stroke(Color.primary.opacity(0.10), lineWidth: 4)
                    Circle().trim(from: 0, to: max(milestone.isCurrent ? 0.025 : 0, milestone.fraction))
                        .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle().fill(milestone.status == .completed || milestone.isCurrent ? tint : Color.primary.opacity(0.04)).padding(8)
                    Image(systemName: milestone.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(milestone.needsReview ? Color.black : milestone.status == .completed || milestone.isCurrent ? Color.white : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                    if milestone.isCurrent {
                        Circle().stroke(tint.opacity(breathing ? 0.10 : 0.35), lineWidth: 2)
                            .scaleEffect(breathing ? 1.14 : 1.04)
                    }
                }
                .frame(width: 64, height: 64)
                .anchorPreference(key: CourseTrailAnchors.self, value: .bounds) { [milestone.id: $0] }
                .frame(width: 98).offset(x: offset)
                VStack(alignment: .leading, spacing: 5) {
                    Text(milestone.title).font(.subheadline.weight(milestone.isCurrent ? .bold : .semibold))
                        .foregroundStyle(milestone.status == .locked ? Color.secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { progressBadge; detailLabel }
                        VStack(alignment: .leading, spacing: 6) { progressBadge; detailLabel }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if milestone.isCurrent { Image(systemName: "arrow.right").font(.caption.bold()).foregroundStyle(labelColor) }
            }.padding(.vertical, 10).padding(.trailing, 14).contentShape(Rectangle())
        }.buttonStyle(CourseTrailButtonStyle()).disabled(milestone.status == .locked)
            .accessibilityLabel("\(milestone.title), \(milestone.showsProgress ? milestone.percentage + " complete, " : "")\(milestone.detail)")
            .onAppear { animateFocus() }
            .onChange(of: milestone.isCurrent) { _, _ in animateFocus() }
    }
    @ViewBuilder private var progressBadge: some View {
        if milestone.showsProgress {
            Text(milestone.percentage).font(.caption.weight(.bold)).monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(labelColor)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.35), lineWidth: 1))
                .fixedSize()
        }
    }
    private var detailLabel: some View {
        Text(milestone.detail).font(.caption)
            .foregroundStyle(milestone.isCurrent ? labelColor : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func animateFocus() {
        guard !reduceMotion, milestone.isCurrent else { breathing = false; return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathing = true }
    }
}

private struct CourseTrailButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CourseMiniTrail: View {
    let milestones: [CourseTrailMilestone]
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: Double {
        guard milestones.count > 1 else { return milestones.first?.fraction ?? 0 }
        let focus = milestones.firstIndex(where: { $0.status != .completed }) ?? milestones.count - 1
        return min(1, (Double(focus) + milestones[focus].fraction) / Double(milestones.count - 1))
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10)).frame(height: 3).padding(.horizontal, 12)
                Capsule().fill(color).frame(width: max(0, geometry.size.width - 24) * fraction, height: 3).padding(.leading, 12)
                HStack(spacing: 0) {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, node in
                        if index > 0 { Spacer(minLength: 0) }
                        ZStack {
                            Circle().fill(node.needsReview ? Color.yellow : Color(.secondarySystemGroupedBackground))
                            Circle().stroke(node.isCurrent || node.status == .completed ? node.tint(color) : Color.primary.opacity(0.15), lineWidth: 2)
                            Circle().trim(from: 0, to: node.fraction).stroke(node.tint(color), lineWidth: 3).rotationEffect(.degrees(-90))
                            Image(systemName: node.needsReview ? "arrow.clockwise" : node.status == .completed ? "checkmark" : node.isCheckpoint ? "flag.fill" : node.isCurrent ? "circle.fill" : "circle")
                                .font(.system(size: node.isCurrent && !node.isCheckpoint && !node.needsReview ? 7 : 9, weight: .bold))
                                .foregroundStyle(node.needsReview ? Color.black : node.isCurrent || node.status == .completed ? node.tint(color) : .secondary)
                        }.frame(width: node.isCurrent ? 28 : 22, height: node.isCurrent ? 28 : 22)
                    }
                }
            }.frame(height: 34)
        }.frame(height: 34)
            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85), value: milestones)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current section learning trail")
            .accessibilityValue(milestones.map { "\($0.title), \($0.showsProgress ? $0.percentage + " complete, " : "")\($0.detail)" }.joined(separator: "; "))
    }
}
