import SwiftUI

/// Temporary Discover experiments. The default deliberately adds no category UI.
enum DiscoverCategoryStyle: String, CaseIterable, Identifiable {
    case none, quietLinks, flagShelf, miniIndex, pocketMenus, browseSwitch

    static let storageKey = "discoverCategoryStyle"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Off"
        case .quietLinks: "Quiet links"
        case .flagShelf: "Flag shelf"
        case .miniIndex: "Mini index"
        case .pocketMenus: "Pocket menus"
        case .browseSwitch: "Browse switch"
        }
    }
    var detail: String {
        switch self {
        case .none: "Keep Discover as it is."
        case .quietLinks: "One quiet line of language and topic links."
        case .flagShelf: "Tiny flags above a thin line of topics."
        case .miniIndex: "A compact, two-row directory."
        case .pocketMenus: "Languages and topics open in a compact inline strip."
        case .browseSwitch: "Switch between a language strip and a topic strip."
        }
    }
}

private enum DiscoverCategoryChoice: Identifiable {
    case all, language(CommunityDeckLanguage), topic(String)

    var id: String {
        switch self {
        case .all: "all"
        case .language(let language): "language:\(language.rawValue)"
        case .topic(let category): "topic:\(category)"
        }
    }
    var title: String {
        switch self {
        case .all: "All"
        case .language(let language): language.title
        case .topic(let category): category == "Exam Prep" ? "Exams" : category
        }
    }
    var flagAsset: String? {
        guard case .language(let language) = self else { return nil }
        return language.discoverFlagAsset
    }
    static var languages: [Self] { CommunityDeckLanguage.allCases.filter { $0 != .all }.map(Self.language) }
    static var topics: [Self] { CommunityFeedView.categories.filter { $0 != "All" }.map(Self.topic) }
}

private extension CommunityDeckLanguage {
    var discoverFlagAsset: String? {
        switch self {
        case .all: nil
        case .english: "FlagUnitedKingdom"
        case .spanish: "FlagSpain"
        case .french: "FlagFrance"
        case .german: "FlagGermany"
        case .italian: "FlagItaly"
        case .portuguese: "FlagPortugal"
        case .korean: "FlagKorea"
        case .japanese: "FlagJapan"
        case .chinese: "FlagChina"
        case .arabic: "FlagSaudiArabia"
        }
    }
}

struct DiscoverCategoryBrowser: View {
    let style: DiscoverCategoryStyle
    @Binding var category: String
    @Binding var language: CommunityDeckLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingLanguages = true
    @State private var pocketPage: PocketPage?

    private enum PocketPage { case languages, topics }

    var body: some View {
        Group {
            switch style {
            case .none: EmptyView()
            case .quietLinks: quietLinks
            case .flagShelf: flagShelf
            case .miniIndex: miniIndex
            case .pocketMenus: pocketMenus
            case .browseSwitch: browseSwitch
            }
        }
        .font(.caption.weight(.medium))
        .tint(LearnAlertStyle.appAccentForeground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browse shared deck categories")
        .onChange(of: style) { _, _ in pocketPage = nil }
    }

    private var quietLinks: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach([DiscoverCategoryChoice.all] + DiscoverCategoryChoice.languages + DiscoverCategoryChoice.topics) { choice in
                    link(choice)
                }
            }
        }
    }

    private var flagShelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    link(.all, compact: true)
                    ForEach(DiscoverCategoryChoice.languages) { choice in link(choice, flagOnly: true, compact: true) }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(DiscoverCategoryChoice.topics) { choice in link(choice, compact: true) }
                }
            }
        }
    }

    private var miniIndex: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], alignment: .center, spacing: 16) {
                ForEach([DiscoverCategoryChoice.all] + DiscoverCategoryChoice.languages + DiscoverCategoryChoice.topics) { choice in
                    Button { select(choice) } label: {
                        HStack(spacing: 5) {
                            Circle().fill(selected(choice) ? LearnAlertStyle.appAccentForeground : .clear).frame(width: 3, height: 3)
                            choiceLabel(choice)
                        }
                        .foregroundStyle(selected(choice) ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                        .frame(minWidth: 78, minHeight: 30, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(selected(choice) ? .isSelected : [])
                }
            }
            .frame(height: 60)
        }
    }

    private var pocketMenus: some View {
        ZStack(alignment: .leading) {
            if let pocketPage {
                pocketChoices(pocketPage)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                pocketOverview
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: pocketPage)
    }

    private var pocketOverview: some View {
        HStack(spacing: 18) {
            link(.all)
            Button {
                HapticFeedback.selection()
                pocketPage = .languages
            } label: {
                HStack(spacing: 5) {
                    if let asset = language.discoverFlagAsset { flag(asset) }
                    else { Image(systemName: "globe").font(.caption) }
                    Text(language == .all ? "Languages" : language.title)
                }
                .foregroundStyle(language == .all ? LearnAlertStyle.textSecondary : LearnAlertStyle.appAccentForeground)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose a language")
            .accessibilityValue(language.title)
            Button {
                HapticFeedback.selection()
                pocketPage = .topics
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2").font(.caption)
                    Text(category == "All" ? "Topics" : category)
                }
                .foregroundStyle(category == "All" ? LearnAlertStyle.textSecondary : LearnAlertStyle.appAccentForeground)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose a topic")
            .accessibilityValue(category == "All" ? "All topics" : category)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    private func pocketChoices(_ page: PocketPage) -> some View {
        HStack(spacing: 10) {
            Button {
                HapticFeedback.selection()
                pocketPage = nil
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.appAccentForeground)
                    .frame(width: 30, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to categories")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    pocketAllChoice(page)
                    ForEach(page == .languages ? DiscoverCategoryChoice.languages : DiscoverCategoryChoice.topics) { choice in
                        link(choice, flagOnly: page == .languages)
                    }
                }
            }
            .id(page)
        }
    }

    private func pocketAllChoice(_ page: PocketPage) -> some View {
        let isSelected = page == .languages ? language == .all : category == "All"
        return Button {
            HapticFeedback.selection()
            if page == .languages { language = .all }
            else { category = "All" }
        } label: {
            Text("All")
                .foregroundStyle(isSelected ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                .frame(minHeight: 36)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(isSelected ? LearnAlertStyle.appAccentForeground.opacity(0.75) : .clear).frame(height: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page == .languages ? "All languages" : "All topics")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var browseSwitch: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                groupButton(languages: true, symbol: "globe")
                groupButton(languages: false, symbol: "square.grid.2x2")
            }
            .background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 13) {
                    link(.all)
                    ForEach(showingLanguages ? DiscoverCategoryChoice.languages : DiscoverCategoryChoice.topics) { choice in
                        link(choice, flagOnly: showingLanguages)
                    }
                }
            }
        }
    }

    private func groupButton(languages: Bool, symbol: String) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { showingLanguages = languages }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(showingLanguages == languages ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary.opacity(0.6))
                .frame(width: 29, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languages ? "Browse languages" : "Browse topics")
        .accessibilityAddTraits(showingLanguages == languages ? .isSelected : [])
    }

    private func link(_ choice: DiscoverCategoryChoice, flagOnly: Bool = false, compact: Bool = false) -> some View {
        Button { select(choice) } label: {
            choiceLabel(choice, flagOnly: flagOnly)
                .foregroundStyle(selected(choice) ? LearnAlertStyle.appAccentForeground : LearnAlertStyle.textSecondary)
                .frame(minHeight: compact ? 29 : 36)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected(choice) ? LearnAlertStyle.appAccentForeground.opacity(0.75) : .clear).frame(height: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(selected(choice) ? .isSelected : [])
    }

    private func choiceLabel(_ choice: DiscoverCategoryChoice, flagOnly: Bool = false) -> some View {
        HStack(spacing: 5) {
            if let asset = choice.flagAsset { flag(asset) }
            if !flagOnly || choice.flagAsset == nil { Text(choice.title).lineLimit(1) }
        }
    }

    private func flag(_ asset: String) -> some View {
        Image(asset).resizable().scaledToFill().frame(width: 22, height: 15).clipped().accessibilityHidden(true)
    }

    private func selected(_ choice: DiscoverCategoryChoice) -> Bool {
        switch choice {
        case .all: category == "All" && language == .all
        case .language(let value): language == value
        case .topic(let value): category == value
        }
    }

    private func select(_ choice: DiscoverCategoryChoice) {
        HapticFeedback.selection()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
            switch choice {
            case .all: category = "All"; language = .all
            case .language(let value): language = language == value ? .all : value
            case .topic(let value): category = category == value ? "All" : value
            }
        }
    }
}
