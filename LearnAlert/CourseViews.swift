//
//  CourseViews.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/20/26.
//

import SwiftUI
import SwiftData

// MARK: - 1. Course Overview View

struct CourseOverviewView: View {
    private let originalCourse: CourseDefinition
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    var course: CourseDefinition { managedCatalog.course(for: originalCourse.id) ?? originalCourse }
    init(course: CourseDefinition) {
        self.originalCourse = course
    }
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progressManager = CourseProgressManager.shared
    @ObservedObject private var engine = StudyEngine.shared

    @State private var showingStarterPreview = false
    @State private var showingVisualStarter = false
    @State private var guideUnit: CourseUnit?
    @State private var showingOnboardingSheet = false
    @State private var showingPathView = false
    @State private var showingReviewSheet = false
    @State private var showingScheduleAlertSuccess = false
    @State private var sampleSelectedAnswer: String?
    @State private var scheduleError: String?

    private var isEnrolled: Bool {
        progressManager.isEnrolled(in: course.id)
    }

    private var currentLesson: CourseLesson? {
        progressManager.currentLesson(for: course)
    }

    private var completionPercent: Double {
        progressManager.completionPercentage(for: course)
    }

    private var completedCards: [CourseLessonCard] {
        progressManager.completedCards(for: course)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                #if DEBUG
                if course.id == "spanish-course" {
                    Button("Preview visual starter · separate progress") { showingStarterPreview = true }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                }
                #endif
                if course.learning?.starter != nil {
                    Button("Start with pictures") { showingVisualStarter = true }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                }
                // Hero Banner Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(course.flagEmoji)
                            .font(.system(size: 40))
                            .padding(8)
                            .background(Color(hex: course.colorHex).opacity(0.14), in: Circle())

                        Spacer()

                        Text(course.levelTag)
                            .font(.custom("Poppins-Bold", size: 11))
                            .foregroundStyle(Color(hex: course.colorHex))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: course.colorHex).opacity(0.14), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.title)
                            .font(.custom("Poppins-Bold", size: 22))
                            .foregroundStyle(LearnAlertStyle.textPrimary)

                        Text(course.summary)
                            .font(.custom("Poppins-Regular", size: 13))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                            .lineSpacing(2)
                    }

                    // Stats Pill Row
                    HStack(spacing: 10) {
                        OverviewStatBadge(icon: "book.pages.fill", title: "\(course.units.count) Units", colorHex: course.colorHex)
                        OverviewStatBadge(icon: "circle.grid.2x2.fill", title: "\(course.totalLessonsCount) Lessons", colorHex: course.colorHex)
                        OverviewStatBadge(icon: "clock.fill", title: "~\(course.estimatedHours)h", colorHex: course.colorHex)
                    }

                    if isEnrolled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(progressManager.completedLessonsCount(for: course)) of \(progressManager.progressLessonsCount(for: course)) Lessons")
                                    .font(.custom("Poppins-SemiBold", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Spacer()
                                Text("\(Int(completionPercent * 100))%")
                                    .font(.custom("Poppins-Bold", size: 12))
                                    .foregroundStyle(Color(hex: course.colorHex))
                            }
                            ProgressView(value: completionPercent)
                                .tint(Color(hex: course.colorHex))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .background(LearnAlertStyle.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Review Learned Material Section (Requirement 12)
                if isEnrolled && !completedCards.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: course.colorHex))
                            Text("Review Learned Material")
                                .font(.custom("Poppins-Bold", size: 15))
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                            Spacer()
                            Text("\(completedCards.count) cards")
                                .font(.custom("Poppins-Medium", size: 11))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                        }

                        HStack(spacing: 10) {
                            Button {
                                showingReviewSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Start Review")
                                        .font(.custom("Poppins-SemiBold", size: 13))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(hex: course.colorHex))
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                scheduleCourseAlerts()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Schedule Alerts")
                                        .font(.custom("Poppins-SemiBold", size: 13))
                                }
                                .foregroundStyle(LearnAlertStyle.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(LearnAlertStyle.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                }

                // Curriculum Units Syllabus
                VStack(alignment: .leading, spacing: 12) {
                    Text("Curriculum")
                        .font(.custom("Poppins-Bold", size: 16))
                        .foregroundStyle(LearnAlertStyle.textPrimary)

                    ForEach(course.units) { unit in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: unit.badgeIcon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: unit.colorHex))
                                Text(unit.title)
                                    .font(.custom("Poppins-Bold", size: 13))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Spacer()
                                Button { guideUnit = unit } label: {
                                    Image(systemName: "book.closed").frame(width: 44, height: 44)
                                }.accessibilityLabel("Section guide: \(unit.title)")
                            }

                            VStack(spacing: 4) {
                                ForEach(unit.lessons) { lesson in
                                    let status = progressManager.getLessonStatus(courseId: course.id, lessonId: lesson.id)
                                    HStack(spacing: 10) {
                                        Image(systemName: status == .completed ? "checkmark.circle.fill" : lesson.nodeType.icon)
                                            .font(.system(size: 11))
                                            .foregroundStyle(status == .completed ? Color.green : Color(hex: unit.colorHex))
                                            .frame(width: 20, height: 20)
                                            .background((status == .completed ? Color.green : Color(hex: unit.colorHex)).opacity(0.14), in: Circle())

                                        Text(lesson.title)
                                            .font(.custom("Poppins-Medium", size: 12))
                                            .foregroundStyle(status == .locked ? LearnAlertStyle.textSecondary.opacity(0.6) : LearnAlertStyle.textPrimary)

                                        Spacer()

                                        Text("\(lesson.cards.count) cards")
                                            .font(.custom("Poppins-Regular", size: 10))
                                            .foregroundStyle(LearnAlertStyle.textSecondary)
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                        .padding(14)
                        .background(LearnAlertStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(LearnAlertStyle.hairline, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Bottom Primary Action
                VStack(spacing: 10) {
                    if isEnrolled {
                        Button {
                            showingPathView = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Continue Learning Path")
                                    .font(.custom("Poppins-SemiBold", size: 15))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: course.colorHex))
                            .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            showingOnboardingSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Start Course")
                                    .font(.custom("Poppins-SemiBold", size: 15))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: course.colorHex))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer().frame(height: 60)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .sheet(isPresented: $showingStarterPreview) { CourseStarterPreviewHost(baseCourse: course) }
        .sheet(isPresented: $showingVisualStarter) { NavigationStack { CourseStarterHomeView(course: course, manager: progressManager) } }
        .navigationTitle(course.language)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $guideUnit) { unit in CourseGuideSheet(course: course, unit: unit) }
        .sheet(isPresented: $showingOnboardingSheet) {
            CourseOnboardingSheet(course: course) {
                showingOnboardingSheet = false
                showingPathView = true
            }
        }
        .fullScreenCover(isPresented: $showingReviewSheet) {
            CourseReviewStudyView(course: course, cards: completedCards) {
                showingReviewSheet = false
                progressManager.reloadFromSharedDefaults()
            }
        }
        .navigationDestination(isPresented: $showingPathView) {
            CoursePathView(course: course)
        }
        .alert("Couldn’t Schedule Alerts", isPresented: Binding(get: { scheduleError != nil }, set: { if !$0 { scheduleError = nil } })) {
            Button("OK", role: .cancel) { scheduleError = nil }
        } message: { Text(scheduleError ?? "") }
        .alert("Review Alerts Scheduled", isPresented: $showingScheduleAlertSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Notification alerts for \(course.title) completed material have been scheduled.")
        }
    }

    private func scheduleCourseAlerts() {
        Task { @MainActor in
            if !NotificationManager.shared.isAuthorized {
                guard await NotificationManager.shared.requestPermission() else {
                    scheduleError = "Enable notifications for LearnAlert in Settings to receive review alerts."
                    return
                }
            }
            do {
                _ = try await engine.startAlerts(for: course, courseReviewOnly: true)
                InteractionSoundPlayer.shared.play(.scheduledAlerts)
                HapticFeedback.success()
                showingScheduleAlertSuccess = true
            } catch {
                scheduleError = error.localizedDescription
                HapticFeedback.warning()
            }
        }
    }
}

private struct OverviewStatBadge: View {
    let icon: String
    let title: String
    let colorHex: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
            Text(title)
                .font(.custom("Poppins-Medium", size: 11))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
}

// MARK: - 2. Course Onboarding Modal Sheet

struct CourseOnboardingSheet: View {
    let course: CourseDefinition
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var progressManager = CourseProgressManager.shared

    @State private var step = 1
    @State private var selectedExperience: CourseExperienceLevel = .absoluteBeginner
    @State private var selectedStudyMode: CourseStudyMode = .inAppAndNotifications
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 18
    @State private var endMinute: Int = 0
    @State private var dailyCardsCount: Int = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Progress Indicator
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { s in
                        Capsule()
                            .fill(s <= step ? Color(hex: course.colorHex) : Color.gray.opacity(0.2))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case 1:
                            experienceStepView
                        case 2:
                            studyModeStepView
                        case 3:
                            planSummaryStepView
                        default:
                            EmptyView()
                        }
                    }
                    .padding(20)
                }

                // Bottom Action Buttons
                HStack(spacing: 12) {
                    if step > 1 {
                        Button {
                            withAnimation(.snappy) { step -= 1 }
                        } label: {
                            Text("Back")
                                .font(.custom("Poppins-SemiBold", size: 14))
                                .foregroundStyle(LearnAlertStyle.textSecondary)
                                .frame(width: 80, height: 46)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if step < 3 {
                            withAnimation(.snappy) { step += 1 }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(step == 3 ? "Start Course" : "Continue")
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color(hex: course.colorHex))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(LearnAlertStyle.surface)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .navigationTitle("Course Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var experienceStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Experience with \(course.language)")
                .font(.custom("Poppins-Bold", size: 18))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            VStack(spacing: 12) {
                ForEach(CourseExperienceLevel.allCases) { exp in
                    let isSelected = selectedExperience == exp
                    Button {
                        withAnimation(.snappy) { selectedExperience = exp }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: exp.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Color(hex: course.colorHex))
                                .frame(width: 38, height: 38)
                                .background(isSelected ? Color(hex: course.colorHex) : Color(hex: course.colorHex).opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(exp.title)
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text(exp.subtitle)
                                    .font(.custom("Poppins-Regular", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: course.colorHex))
                            }
                        }
                        .padding(14)
                        .background(isSelected ? Color(hex: course.colorHex).opacity(0.08) : LearnAlertStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color(hex: course.colorHex) : LearnAlertStyle.hairline, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var studyModeStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Study Mode")
                .font(.custom("Poppins-Bold", size: 18))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            VStack(spacing: 12) {
                ForEach(CourseStudyMode.allCases) { mode in
                    let isSelected = selectedStudyMode == mode
                    Button {
                        withAnimation(.snappy) { selectedStudyMode = mode }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Color(hex: course.colorHex))
                                .frame(width: 38, height: 38)
                                .background(isSelected ? Color(hex: course.colorHex) : Color(hex: course.colorHex).opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.title)
                                    .font(.custom("Poppins-SemiBold", size: 14))
                                    .foregroundStyle(LearnAlertStyle.textPrimary)
                                Text(mode.subtitle)
                                    .font(.custom("Poppins-Regular", size: 12))
                                    .foregroundStyle(LearnAlertStyle.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: course.colorHex))
                            }
                        }
                        .padding(14)
                        .background(isSelected ? Color(hex: course.colorHex).opacity(0.08) : LearnAlertStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color(hex: course.colorHex) : LearnAlertStyle.hairline, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Daily Target Volume
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Alert Cadence")
                    .font(.custom("Poppins-SemiBold", size: 13))
                    .foregroundStyle(LearnAlertStyle.textPrimary)

                HStack(spacing: 8) {
                    ForEach([3, 5, 7, 10], id: \.self) { count in
                        let isSelected = dailyCardsCount == count
                        Button {
                            withAnimation(.snappy) { dailyCardsCount = count }
                        } label: {
                            Text("\(count) cards/day")
                                .font(.custom(isSelected ? "Poppins-Bold" : "Poppins-Medium", size: 12))
                                .foregroundStyle(isSelected ? Color.white : LearnAlertStyle.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(isSelected ? Color(hex: course.colorHex) : LearnAlertStyle.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var planSummaryStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(course.flagEmoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(.custom("Poppins-Bold", size: 17))
                        .foregroundStyle(LearnAlertStyle.textPrimary)
                    Text(course.levelTag)
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(LearnAlertStyle.textSecondary)
                }
            }

            VStack(spacing: 10) {
                PlanSummaryRow(label: "Experience", value: selectedExperience.title, icon: selectedExperience.icon, colorHex: course.colorHex)
                PlanSummaryRow(label: "Study Mode", value: selectedStudyMode.title, icon: selectedStudyMode.icon, colorHex: course.colorHex)
                PlanSummaryRow(label: "Cadence", value: "\(dailyCardsCount) alerts / day", icon: "bell.badge.fill", colorHex: course.colorHex)
            }
            .padding(14)
            .background(LearnAlertStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LearnAlertStyle.hairline, lineWidth: 1)
            )
        }
    }

    private func completeOnboarding() {
        _ = progressManager.enroll(
            course: course,
            goal: progressManager.enrollment(for: course.id)?.goal ?? .conversation,
            experienceLevel: selectedExperience,
            studyMode: selectedStudyMode,
            selectedDays: Array(selectedDays),
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            dailyCardsTarget: dailyCardsCount,
            context: context
        )
        HapticFeedback.success()
        InteractionSoundPlayer.shared.play(.addDeck)
        onFinish()
    }
}

private struct PlanSummaryRow: View {
    let label: String
    let value: String
    let icon: String
    let colorHex: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 24)
            Text(label)
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundStyle(LearnAlertStyle.textSecondary)
            Spacer()
            Text(value)
                .font(.custom("Poppins-SemiBold", size: 12))
                .foregroundStyle(LearnAlertStyle.textPrimary)
        }
    }
}

// MARK: - 3. Course Path View (Interactive Scrollable Journey)

struct CoursePathView: View {
    private let originalCourse: CourseDefinition
    @ObservedObject private var managedCatalog = ManagedCatalogStore.shared
    var course: CourseDefinition { managedCatalog.course(for: originalCourse.id) ?? originalCourse }
    init(course: CourseDefinition, initialCheckpointSectionId: String? = nil) {
        self.originalCourse = course
        self.initialCheckpointSectionId = initialCheckpointSectionId
    }
    var initialCheckpointSectionId: String? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var manager = CourseProgressManager.shared
    @State private var guideUnit: CourseUnit?
    @State private var selectedLesson: CourseLesson?
    @State private var selectedCheckpoint: CourseUnit?
    @State private var showingReview = false
    @State private var showingInfo = false
    @State private var showingOnboarding = false
    @State private var lessonAfterEnrollment: CourseLesson?
    private var trail: CourseTrailProjection { CourseTrailProjection(course: course, snapshot: manager.learningSnapshot) }
    private var enrolled: Bool { manager.isEnrolled(in: course.id) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    HStack(spacing: 12) {
                        Text(course.flagEmoji).font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.title).font(.title3.bold())
                            Text("\(trail.progressMilestones.filter { $0.status == .completed }.count) of \(trail.progressMilestones.count) milestones")
                                .font(.caption).foregroundStyle(.secondary).contentTransition(.numericText())
                        }
                        Spacer()
                        if !manager.completedCards(for: course).isEmpty {
                            Button { showingReview = true } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                                .accessibilityLabel("Review learned material")
                        }
                    }.padding(.horizontal, 24)
                    ForEach(course.units) { unit in
                        VStack(spacing: 18) {
                            HStack(spacing: 10) {
                                Label(unit.title, systemImage: unit.badgeIcon).font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Button { guideUnit = unit } label: { Image(systemName: "book.closed").frame(width: 44, height: 44) }
                                    .accessibilityLabel("Section guide: \(unit.title)")
                            }.foregroundStyle(Color(hex: unit.colorHex)).padding(.horizontal, 24)
                            CourseConnectedTrail(milestones: trail.milestones.filter { $0.unitId == unit.id },
                                                 color: Color(hex: unit.colorHex), select: open)
                                .padding(.horizontal, 12)
                        }
                    }
                    Color.clear.frame(height: 12)
                }.padding(.top, 18).padding(.bottom, 20)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .onAppear {
                manager.reloadFromSharedDefaults()
                if let id = initialCheckpointSectionId, let unit = course.units.first(where: { $0.id == id }),
                   manager.getCheckpointStatus(courseId: course.id, sectionId: id) == .available { selectedCheckpoint = unit }
            }
            .task { await Task.yield(); if let id = trail.focus?.id { proxy.scrollTo(id, anchor: .center) } }
            .onChange(of: trail.focus?.id) { _, id in
                guard let id else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.88)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .navigationTitle("Learning Path").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingInfo = true } label: { Image(systemName: "info.circle") }.accessibilityLabel("Course details and settings")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                if !enrolled { showingOnboarding = true }
                else if let focus = trail.focus, focus.status != .completed { open(focus) }
                else { showingReview = true }
            } label: {
                HStack {
                    Text(!enrolled ? "Start \(course.language)" : trail.focus?.isCheckpoint == true && trail.focus?.status != .completed ? (trail.focus?.needsReview == true ? "Retry checkpoint" : "Take checkpoint") : trail.focus?.needsReview == true ? "Review lesson" : trail.focus?.status == .completed ? "Review" : "Continue")
                    Image(systemName: "arrow.right")
                }.font(.headline).frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.borderedProminent).tint(Color(hex: course.colorHex))
                .padding(.horizontal, 24).padding(.vertical, 12).background(.regularMaterial)
        }
        .sheet(item: $guideUnit) { CourseGuideSheet(course: course, unit: $0) }
        .sheet(isPresented: $showingInfo) {
            NavigationStack {
                CourseOverviewView(course: course).toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { showingInfo = false } }
                }
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            CourseOnboardingSheet(course: course) {
                showingOnboarding = false
                manager.reloadFromSharedDefaults()
                if let lessonAfterEnrollment { selectedLesson = lessonAfterEnrollment; self.lessonAfterEnrollment = nil }
            }
        }
        .fullScreenCover(item: $selectedLesson) { lesson in
            CourseLessonStudyView(course: course, lesson: lesson) { selectedLesson = nil; manager.reloadFromSharedDefaults() }
        }
        .fullScreenCover(item: $selectedCheckpoint) { unit in
            CourseCheckpointStudyView(course: course, unit: unit) { selectedCheckpoint = nil; manager.reloadFromSharedDefaults() }
        }
        .fullScreenCover(isPresented: $showingReview) {
            CourseReviewStudyView(course: course, cards: manager.completedCards(for: course)) { showingReview = false; manager.reloadFromSharedDefaults() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { manager.reloadFromSharedDefaults() } }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.88), value: trail)
    }
    private func open(_ node: CourseTrailMilestone) {
        guard node.status != .locked else { return }
        if node.isCheckpoint {
            if enrolled { selectedCheckpoint = course.units.first { $0.id == node.unitId } }
            else { showingOnboarding = true }
        } else if let lesson = course.units.flatMap(\.lessons).first(where: { $0.id == node.id }) {
            if enrolled { selectedLesson = lesson }
            else { lessonAfterEnrollment = lesson; showingOnboarding = true }
        }
    }
}

// MARK: - Course Path Node View

private struct CoursePathNodeView: View {
    let lesson: CourseLesson
    let status: LessonStatus
    let colorHex: String
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Button {
                onTap()
            } label: {
                ZStack {
                    // Outer Ring
                    Circle()
                        .stroke(
                            status == .current ? Color(hex: colorHex) : (status == .completed ? Color.green.opacity(0.8) : Color.gray.opacity(0.2)),
                            lineWidth: status == .current ? 3.5 : 2
                        )
                        .frame(width: 64, height: 64)

                    // Inner Node
                    Circle()
                        .fill(nodeFillColor)
                        .frame(width: 50, height: 50)
                        .shadow(color: status == .current ? Color(hex: colorHex).opacity(0.35) : Color.black.opacity(0.06), radius: 5, y: 2)

                    // Icon
                    Image(systemName: nodeIcon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(nodeIconColor)

                    // Checkmark Badge for Completed
                    if status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.green)
                            .background(Color.white, in: Circle())
                            .offset(x: 20, y: -20)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(status == .locked)

            // Title Label
            Text(lesson.title)
                .font(.custom("Poppins-SemiBold", size: 11))
                .foregroundStyle(status == .locked ? LearnAlertStyle.textSecondary.opacity(0.6) : LearnAlertStyle.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 150)
        }
    }

    private var nodeFillColor: Color {
        switch status {
        case .locked:
            return Color.gray.opacity(0.12)
        case .current:
            return Color(hex: colorHex)
        case .completed:
            return Color.green
        case .available, .reviewDue:
            return Color(hex: colorHex).opacity(0.20)
        }
    }

    private var nodeIconColor: Color {
        switch status {
        case .locked:
            return Color.gray.opacity(0.5)
        case .current, .completed:
            return Color.white
        case .available, .reviewDue:
            return Color(hex: colorHex)
        }
    }

    private var nodeIcon: String {
        switch status {
        case .locked:
            return "lock.fill"
        default:
            return lesson.nodeType.icon
        }
    }
}

// MARK: - 4. Course Lesson Study View (Interactive Quiz Session)

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("Poppins-Bold", size: 16))
                .foregroundStyle(LearnAlertStyle.textPrimary)
            Text(title)
                .font(.custom("Poppins-Regular", size: 11))
                .foregroundStyle(LearnAlertStyle.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LearnAlertStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}


/// Visible after re-upgrade; nothing claims a silent or seamless history merge.
struct CourseProgressRecoveryBanner: View {
    @ObservedObject private var manager: CourseProgressManager
    init(manager: CourseProgressManager = .shared) { _manager = ObservedObject(wrappedValue: manager) }
    @State private var showingRecovery = false
    var body: some View {
        if let notice = manager.progressRecoveryNotice ?? manager.progressReadError.map({ "Course progress couldn’t be loaded. Your saved files haven’t been replaced. " + $0 }) {
            Button { showingRecovery = true } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.progressRecoveryNotice != nil ? "Older progress found" : "Progress needs attention").font(.headline)
                        Text(manager.progressRecoveryNotice != nil
                             ? "Older work hasn’t been added. Review and export histories."
                             : "Saved files are unchanged. Review recovery.")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(.primary).frame(minHeight: 44)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
            }.buttonStyle(.plain)
                .accessibilityHint(notice + " Opens the recovery explanation and export action.")
                .sheet(isPresented: $showingRecovery) { CourseProgressRecoverySheet(manager: manager) }
        }
    }
}
private struct CourseProgressRecoverySheet: View {
    @ObservedObject private var manager: CourseProgressManager
    init(manager: CourseProgressManager = .shared) { _manager = ObservedObject(wrappedValue: manager) }
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Keep both progress histories").font(.title2.bold())
                    Text("Your current history stays active. Work saved by an older app version is preserved separately and has not been added to your lessons, scores or reviews.")
                    Text("The recovery file includes both histories and the original source records. Exporting does not combine or automatically restore them. LearnAlert has not sent these files anywhere.")
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Export both histories", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                            .buttonStyle(.borderedProminent)
                    } else { Button("Prepare recovery export", action: prepare).frame(minHeight: 44) }
                    if let error { Text(error).foregroundStyle(.red).font(.callout) }
                }.padding(24)
            }.navigationTitle("Progress recovery").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func prepare() {
        do { exportURL = try manager.exportProgressRecovery(); error = nil }
        catch { self.error = "The export couldn’t be prepared. Your histories remain saved. " + error.localizedDescription }
    }
}
