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
    let course: CourseDefinition
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var progressManager = CourseProgressManager.shared
    @ObservedObject private var engine = StudyEngine.shared

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
                                Text("\(progressManager.completedLessonsCount(for: course)) of \(course.totalLessonsCount) Lessons")
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
        let deck = progressManager.createOrSyncCourseDeck(for: course, in: context)
        Task { @MainActor in
            if !NotificationManager.shared.isAuthorized {
                guard await NotificationManager.shared.requestPermission() else {
                    scheduleError = "Enable notifications for LearnAlert in Settings to receive review alerts."
                    return
                }
            }
            do {
                _ = try await engine.startAlerts(for: deck, courseReviewOnly: true)
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
    @State private var selectedGoal: CourseGoal = .conversation
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
                    ForEach(1...4, id: \.self) { s in
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
                            goalStepView
                        case 2:
                            experienceStepView
                        case 3:
                            studyModeStepView
                        case 4:
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
                        if step < 4 {
                            withAnimation(.snappy) { step += 1 }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(step == 4 ? "Start Course" : "Continue")
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
            .navigationTitle("Personalize Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var goalStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What's your primary goal?")
                .font(.custom("Poppins-Bold", size: 18))
                .foregroundStyle(LearnAlertStyle.textPrimary)

            VStack(spacing: 10) {
                ForEach(CourseGoal.allCases) { goal in
                    let isSelected = selectedGoal == goal
                    Button {
                        withAnimation(.snappy) { selectedGoal = goal }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Color(hex: course.colorHex))
                                .frame(width: 38, height: 38)
                                .background(isSelected ? Color(hex: course.colorHex) : Color(hex: course.colorHex).opacity(0.12), in: Circle())

                            Text(goal.title)
                                .font(.custom("Poppins-SemiBold", size: 14))
                                .foregroundStyle(LearnAlertStyle.textPrimary)

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
                PlanSummaryRow(label: "Primary Goal", value: selectedGoal.title, icon: selectedGoal.icon, colorHex: course.colorHex)
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
            goal: selectedGoal,
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
    let course: CourseDefinition
    var initialCheckpointSectionId: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var progressManager = CourseProgressManager.shared
    @ObservedObject private var engine = StudyEngine.shared

    @State private var guideUnit: CourseUnit?
    @State private var selectedLessonForStudy: CourseLesson?
    @State private var showingReviewSheet = false
    @State private var selectedCheckpoint: CourseUnit?
    @State private var showingScheduleAlertSuccess = false

    private var completedCards: [CourseLessonCard] {
        progressManager.completedCards(for: course)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Course Header Card
                HStack(spacing: 12) {
                    Text(course.flagEmoji)
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.title)
                            .font(.custom("Poppins-Bold", size: 17))
                            .foregroundStyle(LearnAlertStyle.textPrimary)
                        Text("\(progressManager.completedLessonsCount(for: course)) of \(course.totalLessonsCount) Lessons Completed")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    Spacer()

                    if !completedCards.isEmpty {
                        Button {
                            showingReviewSheet = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color(hex: course.colorHex))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Review learned material")
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

                // Units & Journey Nodes
                ForEach(course.units) { unit in
                    VStack(spacing: 14) {
                        // Unit Header Pill
                        HStack(spacing: 8) {
                            Image(systemName: unit.badgeIcon)
                                .font(.system(size: 11, weight: .bold))
                            Text(unit.title)
                                .font(.custom("Poppins-Bold", size: 12))
                        }
                        .foregroundStyle(Color(hex: unit.colorHex))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: unit.colorHex).opacity(0.14), in: Capsule())

                        Button { guideUnit = unit } label: {
                            Label("Section guide", systemImage: "book.closed").font(.subheadline.weight(.medium)).frame(minHeight: 44)
                        }.accessibilityLabel("Section guide: \(unit.title)")

                        // Staggered Path Nodes
                        VStack(spacing: 16) {
                            ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                                let status = progressManager.getLessonStatus(courseId: course.id, lessonId: lesson.id)
                                let xOffset: CGFloat = (index % 3 == 1) ? 35 : ((index % 3 == 2) ? -35 : 0)

                                CoursePathNodeView(
                                    lesson: lesson,
                                    status: status,
                                    colorHex: unit.colorHex,
                                    onTap: {
                                        if status != .locked {
                                            selectedLessonForStudy = lesson
                                        }
                                    }
                                )
                                .offset(x: xOffset)
                            }
                            if let quiz = unit.checkpointQuiz {
                                let status = progressManager.getCheckpointStatus(courseId: course.id, sectionId: unit.id)
                                Button { selectedCheckpoint = unit } label: {
                                    VStack(spacing: 7) {
                                        Image(systemName: status == .completed ? "checkmark.seal.fill" : status == .locked ? "lock.fill" : "checkmark.shield.fill")
                                            .font(.system(size: 25)).frame(width: 68, height: 68)
                                            .background(Color(hex: unit.colorHex).opacity(status == .locked ? 0.08 : 0.18), in: Circle())
                                        Text("Checkpoint").font(.custom("Poppins-SemiBold", size: 12))
                                        Text(status == .completed ? "Passed" : "\(quiz.questions.count) questions · \(Int(quiz.passingScoreThreshold * 100))% to pass")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }.foregroundStyle(status == .locked ? Color.gray : Color(hex: unit.colorHex))
                                }.buttonStyle(.plain).disabled(status == .locked)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Spacer().frame(height: 80)
            }
            .padding(.top, 14)
        }
        .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
        .navigationTitle("Learning Path")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $guideUnit) { unit in CourseGuideSheet(course: course, unit: unit) }
        .fullScreenCover(item: $selectedLessonForStudy) { lesson in
            CourseLessonStudyView(course: course, lesson: lesson) {
                selectedLessonForStudy = nil
                progressManager.reloadFromSharedDefaults()
            }
        }
        .fullScreenCover(item: $selectedCheckpoint) { unit in
            CourseCheckpointStudyView(course: course, unit: unit) {
                selectedCheckpoint = nil
                progressManager.reloadFromSharedDefaults()
            }
        }
        .onAppear {
            progressManager.reloadFromSharedDefaults()
            if let id = initialCheckpointSectionId, let unit = course.units.first(where: { $0.id == id }),
               progressManager.getCheckpointStatus(courseId: course.id, sectionId: id) == .available { selectedCheckpoint = unit }
        }
        .fullScreenCover(isPresented: $showingReviewSheet) {
            CourseReviewStudyView(course: course, cards: completedCards) {
                showingReviewSheet = false
                progressManager.reloadFromSharedDefaults()
            }
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
