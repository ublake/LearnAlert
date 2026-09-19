import SwiftUI
import PDFKit

public struct PDFSectionPickerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    public let document: PDFDocument
    public let sections: [PDFSectionItem]
    public let sourceName: String
    public let detectionMethod: PDFOutlineManager.DetectionMethod
    public let onConfirm: (Data, String, String?) -> Void
    public let onCancel: () -> Void

    private let maxPageLimit: Int = 20

    @State private var selectedPageIndices: Set<Int> = []
    @State private var selectedSectionIDs: Set<String> = []
    @State private var selectedTab: PickerTab = .sections
    @State private var customRangeStartText: String = ""
    @State private var customRangeEndText: String = ""
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var isFrontMatterExpanded: Bool = false

    public enum PickerTab: String, CaseIterable {
        case sections = "Sections"
        case pages = "Pages"
    }

    private func isFrontMatterOrContentless(_ section: PDFSectionItem) -> Bool {
        if section.kind == .frontMatter || section.isContentless {
            return true
        }
        let lower = section.title.lowercased()
        let frontMatterKeywords = [
            "cover", "title page", "title", "table of contents", "contents", "toc",
            "copyright", "dedication", "epigraph", "preface", "foreword",
            "acknowledgement", "acknowledgment", "front matter", "frontmatter",
            "credits", "about the author", "publisher", "índice", "prefacio", "sumario"
        ]
        if frontMatterKeywords.contains(where: { lower.contains($0) }) {
            return true
        }
        if section.startPageIndex == 0 && section.pageCount <= 1 {
            return true
        }
        return false
    }

    private var contentSections: [PDFSectionItem] {
        let content = sections.filter { !isFrontMatterOrContentless($0) }
        return content.isEmpty ? sections : content
    }

    private var frontMatterSections: [PDFSectionItem] {
        if contentSections.count == sections.count {
            return []
        }
        return sections.filter { isFrontMatterOrContentless($0) }
    }

    public init(
        document: PDFDocument,
        sections: [PDFSectionItem],
        sourceName: String,
        detectionMethod: PDFOutlineManager.DetectionMethod,
        onConfirm: @escaping (Data, String, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.document = document
        self.sections = sections
        self.sourceName = sourceName
        self.detectionMethod = detectionMethod
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedTab = State(initialValue: sections.isEmpty ? .pages : .sections)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header document info
                    documentHeaderView

                    // Mode switch: Sections vs Pages
                    Picker("Mode", selection: $selectedTab) {
                        Text(PickerTab.sections.rawValue).tag(PickerTab.sections)
                        Text(PickerTab.pages.rawValue).tag(PickerTab.pages)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Main Content
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedTab {
                            case .sections:
                                sectionsListView
                            case .pages:
                                pagesView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }

                    // Bottom sticky summary & confirmation
                    footerActionView
                }
            }
            .navigationTitle("Select PDF Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LearnAlertStyle.courseCanvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.custom("Poppins-Medium", size: 14))
                    .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !selectedPageIndices.isEmpty {
                        Button("Clear All") {
                            clearAllSelections()
                        }
                        .font(.custom("Poppins-Medium", size: 13))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                    }
                }
            }
            .onAppear {
                setupInitialSelection()
            }
        }
    }

    // MARK: - Header

    private var documentHeaderView: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 22))
                .foregroundStyle(LearnAlertStyle.indigo)
                .frame(width: 44, height: 44)
                .background(LearnAlertStyle.indigo.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(sourceName)
                    .font(.custom("Poppins-SemiBold", size: 14))
                    .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(document.pageCount) total pages")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.3))

                    Text(detectionMethod.rawValue)
                        .font(.custom("Poppins-Medium", size: 10))
                        .foregroundStyle(Color(hex: "#00B4D8"))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(colorScheme == .light ? Color.black.opacity(0.03) : Color.white.opacity(0.04))
    }

    // MARK: - Sections List View with Horizontal Thumbnail Preview

    private var sectionsListView: some View {
        VStack(spacing: 10) {
            if contentSections.isEmpty && frontMatterSections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                    Text("No Sections Detected")
                        .font(.custom("Poppins-SemiBold", size: 15))
                        .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                    Text("This document does not contain embedded bookmarks or detected chapters. You can select specific pages using the Pages tab.")
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Front Matter Dropdown (Closed by default)
                if !frontMatterSections.isEmpty {
                    frontMatterDropdownView
                }

                // Regular Content Sections
                ForEach(contentSections) { section in
                    sectionRow(for: section)
                }
            }
        }
    }

    private func sectionRow(for section: PDFSectionItem) -> some View {
        let isSelected = selectedSectionIDs.contains(section.id)
        let rowBackground: Color = isSelected
            ? (colorScheme == .light ? Color.white.opacity(0.92) : Color.white.opacity(0.08))
            : (colorScheme == .light ? Color.white.opacity(0.65) : Color.white.opacity(0.03))
        let rowStrokeColor: Color = isSelected
            ? LearnAlertStyle.indigo.opacity(0.4)
            : (colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.06))
        let pageCountColor: Color = section.pageCount > maxPageLimit
            ? Color.orange
            : (colorScheme == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
        let checkmarkColor: Color = isSelected
            ? LearnAlertStyle.indigo
            : (colorScheme == .light ? Color.black.opacity(0.35) : Color.white.opacity(0.35))

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                toggleSection(section)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(checkmarkColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(section.title)
                                .font(.custom("Poppins-SemiBold", size: 14))
                                .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                                .lineLimit(1)

                            Spacer()

                            kindBadge(for: section.kind)
                        }

                        HStack(spacing: 5) {
                            if section.startPageIndex == section.endPageIndex {
                                Text("Page \(section.startPageIndex + 1)")
                                    .font(.custom("Poppins-Regular", size: 11))
                                    .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                            } else {
                                Text("Pages \(section.startPageIndex + 1)–\(section.endPageIndex + 1)")
                                    .font(.custom("Poppins-Regular", size: 11))
                                    .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                            }

                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.3))

                            Text("\(section.pageCount) \(section.pageCount == 1 ? "page" : "pages")")
                                .font(.custom("Poppins-Medium", size: 11))
                                .foregroundStyle(pageCountColor)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Horizontal Thumbnail Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(section.startPageIndex...section.endPageIndex, id: \.self) { pageIndex in
                        let pageSelected = selectedPageIndices.contains(pageIndex)
                        SectionPageThumbnailItem(
                            document: document,
                            pageIndex: pageIndex,
                            isSelected: pageSelected,
                            onToggle: { toggleSinglePage(pageIndex) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
        .shadow(color: colorScheme == .light ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
    }

    // MARK: - Front Matter Dropdown (Closed by Default)

    private var frontMatterDropdownView: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    isFrontMatterExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.45) : Color.white.opacity(0.45))

                    Text("Front Matter")
                        .font(.custom("Poppins-Medium", size: 13))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.85) : Color.white.opacity(0.8))

                    Text("(\(frontMatterSections.count) \(frontMatterSections.count == 1 ? "section" : "sections"))")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.45) : Color.white.opacity(0.45))

                    Spacer()

                    Image(systemName: isFrontMatterExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colorScheme == .light ? Color.white.opacity(0.70) : Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isFrontMatterExpanded {
                VStack(spacing: 6) {
                    ForEach(frontMatterSections) { section in
                        frontMatterSectionRow(for: section)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func frontMatterSectionRow(for section: PDFSectionItem) -> some View {
        let isSelected = selectedSectionIDs.contains(section.id)
        let checkmarkColor: Color = isSelected
            ? LearnAlertStyle.indigo
            : (colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
        let rowStrokeColor: Color = isSelected
            ? LearnAlertStyle.indigo.opacity(0.3)
            : (colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.05))
        let rowBgColor: Color = colorScheme == .light ? Color.white.opacity(0.65) : Color.white.opacity(0.025)

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    toggleSection(section)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(checkmarkColor)
                }
                .buttonStyle(.plain)

                Text(section.title)
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.80) : Color.white.opacity(0.75))
                    .lineLimit(1)

                if section.startPageIndex == section.endPageIndex {
                    Text("\(section.startPageIndex + 1)")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.50) : Color.white.opacity(0.45))
                } else {
                    Text("\(section.startPageIndex + 1)–\(section.endPageIndex + 1)")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.50) : Color.white.opacity(0.45))
                }

                Spacer()

                kindBadge(for: section.kind)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // Horizontal thumbnail row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(section.startPageIndex...section.endPageIndex, id: \.self) { pageIndex in
                        let pageSelected = selectedPageIndices.contains(pageIndex)
                        FrontMatterThumbnailItem(
                            document: document,
                            pageIndex: pageIndex,
                            isSelected: pageSelected,
                            onToggle: { toggleSinglePage(pageIndex) }
                        )
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(rowBgColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
    }

    private func kindBadge(for kind: PDFSectionKind) -> some View {
        HStack(spacing: 4) {
            Image(systemName: kind.iconName)
                .font(.system(size: 9))
            Text(kind.displayTitle)
                .font(.custom("Poppins-Medium", size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(kindBadgeColor(for: kind).opacity(0.18))
        .foregroundStyle(kindBadgeColor(for: kind))
        .clipShape(Capsule())
    }

    private func kindBadgeColor(for kind: PDFSectionKind) -> Color {
        switch kind {
        case .module: return Color(hex: "#7A5AF8")
        case .chapter: return Color(hex: "#5B78C7")
        case .section: return Color(hex: "#00B4D8")
        case .frontMatter, .backMatter: return Color.gray
        case .other: return Color.purple
        }
    }

    // MARK: - Pages View (Merged Visual Grid + Tiny Custom Range Box)

    private var pagesView: some View {
        VStack(spacing: 12) {
            // Tiny custom range UI box at top (empty by default)
            customRangeMiniBox

            // Thumbnail Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 12)], spacing: 12) {
                ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                    let isSelected = selectedPageIndices.contains(pageIndex)
                    PageGridThumbnailItem(
                        document: document,
                        pageIndex: pageIndex,
                        isSelected: isSelected,
                        onToggle: { toggleSinglePage(pageIndex) }
                    )
                }
            }
        }
    }

    // MARK: - Tiny Custom Range Box at Top of Pages

    private var customRangeMiniBox: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "number")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LearnAlertStyle.indigo)
                Text("Select Range:")
                    .font(.custom("Poppins-Medium", size: 12))
                    .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.85) : Color.white.opacity(0.85))
            }

            TextField("From", text: $customRangeStartText)
                .keyboardType(.numberPad)
                .font(.custom("Poppins-SemiBold", size: 12))
                .multilineTextAlignment(.center)
                .frame(width: 48, height: 32)
                .background(colorScheme == .light ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(colorScheme == .light ? Color.black.opacity(0.15) : Color.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(colorScheme == .light ? Color.black : .white)

            Text("–")
                .font(.custom("Poppins-Regular", size: 12))
                .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.4) : Color.white.opacity(0.4))

            TextField("To", text: $customRangeEndText)
                .keyboardType(.numberPad)
                .font(.custom("Poppins-SemiBold", size: 12))
                .multilineTextAlignment(.center)
                .frame(width: 48, height: 32)
                .background(colorScheme == .light ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(colorScheme == .light ? Color.black.opacity(0.15) : Color.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(colorScheme == .light ? Color.black : .white)

            Button("Select") {
                applyTypedRange()
            }
            .font(.custom("Poppins-SemiBold", size: 11))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LearnAlertStyle.indigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !selectedPageIndices.isEmpty {
                Button("Clear") {
                    clearAllSelections()
                }
                .font(.custom("Poppins-Medium", size: 11))
                .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.55))
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(colorScheme == .light ? Color.white.opacity(0.75) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Footer & Live Selection

    private var footerActionView: some View {
        VStack(spacing: 10) {
            // Error / limit banner if any
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.orange)
                    Text(errorMessage)
                        .font(.custom("Poppins-Regular", size: 12))
                        .foregroundStyle(Color.orange.opacity(0.95))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Live page counter & action button
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(selectedPageIndices.count) / \(maxPageLimit) Pages")
                            .font(.custom("Poppins-SemiBold", size: 14))
                            .foregroundStyle(colorScheme == .light ? Color.black : Color.white)

                        if selectedPageIndices.count >= maxPageLimit {
                            Text("Max")
                                .font(.custom("Poppins-Bold", size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(Color.orange)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Selected for AI flashcards")
                        .font(.custom("Poppins-Regular", size: 11))
                        .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.6))
                }

                Spacer()

                Button {
                    exportAndConfirmSubset()
                } label: {
                    HStack(spacing: 6) {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 13, weight: .bold))
                            Text(selectedPageIndices.isEmpty ? "Select Pages" : "Use \(selectedPageIndices.count) \(selectedPageIndices.count == 1 ? "Page" : "Pages")")
                                .font(.custom("Poppins-SemiBold", size: 13))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .foregroundStyle(.white)
                    .background(selectedPageIndices.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LearnAlertStyle.indigo))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(selectedPageIndices.isEmpty || isExporting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(LearnAlertStyle.courseCanvas.opacity(0.95))
                .ignoresSafeArea()
        )
    }

    // MARK: - Logic & Actions

    private func setupInitialSelection() {
        selectedSectionIDs = []
        selectedPageIndices = []
        customRangeStartText = ""
        customRangeEndText = ""
        isFrontMatterExpanded = false
    }

    private func clearAllSelections() {
        errorMessage = nil
        selectedSectionIDs.removeAll()
        selectedPageIndices.removeAll()
        customRangeStartText = ""
        customRangeEndText = ""
    }

    private func toggleSection(_ section: PDFSectionItem) {
        errorMessage = nil
        let pageRange = section.startPageIndex...section.endPageIndex
        if selectedSectionIDs.contains(section.id) {
            selectedSectionIDs.remove(section.id)
            selectedPageIndices.subtract(pageRange)
        } else {
            let wouldSelect = selectedPageIndices.union(pageRange)
            if wouldSelect.count > maxPageLimit {
                errorMessage = "Maximum \(maxPageLimit) pages allowed per deck (selecting this would reach \(wouldSelect.count) pages). Please deselect other sections first."
                return
            }
            selectedSectionIDs.insert(section.id)
            selectedPageIndices.formUnion(pageRange)
        }
    }

    private func applyTypedRange() {
        guard let start = Int(customRangeStartText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let end = Int(customRangeEndText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        let clampedStart = max(1, min(start, document.pageCount))
        let clampedEnd = max(clampedStart, min(end, document.pageCount))
        let count = clampedEnd - clampedStart + 1
        if count > maxPageLimit {
            errorMessage = "Maximum \(maxPageLimit) pages allowed. Clamped to \(maxPageLimit) pages."
            let finalEnd = clampedStart + maxPageLimit - 1
            selectedPageIndices = Set((clampedStart - 1)...(finalEnd - 1))
        } else {
            errorMessage = nil
            selectedPageIndices = Set((clampedStart - 1)...(clampedEnd - 1))
        }
        syncSectionsFromPageIndices()
    }

    private func toggleSinglePage(_ pageIndex: Int) {
        errorMessage = nil
        if selectedPageIndices.contains(pageIndex) {
            selectedPageIndices.remove(pageIndex)
        } else {
            if selectedPageIndices.count >= maxPageLimit {
                errorMessage = "Maximum \(maxPageLimit) pages allowed per deck generation."
                return
            }
            selectedPageIndices.insert(pageIndex)
        }
        syncSectionsFromPageIndices()
    }

    private func syncSectionsFromPageIndices() {
        var activeIDs = Set<String>()
        for section in sections {
            let sectionPages = Set(section.startPageIndex...section.endPageIndex)
            if !sectionPages.isEmpty && sectionPages.isSubset(of: selectedPageIndices) {
                activeIDs.insert(section.id)
            }
        }
        selectedSectionIDs = activeIDs
    }

    private func exportAndConfirmSubset() {
        guard !selectedPageIndices.isEmpty else { return }
        isExporting = true
        errorMessage = nil

        let baseName = (sourceName as NSString).deletingPathExtension
        let sorted = selectedPageIndices.sorted()
        let folderTitle: String?
        if let first = sorted.first, let last = sorted.last {
            if first == last {
                folderTitle = "Page \(first + 1)"
            } else {
                folderTitle = "Pages \(first + 1)–\(last + 1)"
            }
        } else {
            folderTitle = nil
        }

        let formattedSectionName: String
        if let folderTitle {
            formattedSectionName = "\(baseName) (\(folderTitle))"
        } else {
            formattedSectionName = baseName
        }

        let doc = self.document
        let pagesToExport = self.selectedPageIndices

        Task {
            do {
                let subsetData = try PDFOutlineManager.createSubset(from: doc, selectedPageIndices: pagesToExport)
                self.isExporting = false
                self.onConfirm(subsetData, formattedSectionName, folderTitle)
            } catch {
                self.isExporting = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Subviews for Compact & Type-Safe Rendering

private struct PageGridThumbnailItem: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                PDFThumbnailView(
                    document: document,
                    pageIndex: pageIndex,
                    size: CGSize(width: 80, height: 110)
                )
                .frame(height: 105)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                )

                // Compact page number inside bottom-right (no "p.")
                Text("\(pageIndex + 1)")
                    .font(.custom("Poppins-SemiBold", size: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(4)

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(LearnAlertStyle.indigo)
                        .background(Circle().fill(Color.black))
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SectionPageThumbnailItem: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                PDFThumbnailView(
                    document: document,
                    pageIndex: pageIndex,
                    size: CGSize(width: 52, height: 72)
                )
                .frame(width: 52, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
                )

                // Compact page number inside bottom-right (no "p.")
                Text("\(pageIndex + 1)")
                    .font(.custom("Poppins-SemiBold", size: 9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(3)

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(LearnAlertStyle.indigo)
                        .background(Circle().fill(Color.black))
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FrontMatterThumbnailItem: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                PDFThumbnailView(
                    document: document,
                    pageIndex: pageIndex,
                    size: CGSize(width: 44, height: 60)
                )
                .frame(width: 44, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )

                // Compact page number inside bottom-right (no "p.")
                Text("\(pageIndex + 1)")
                    .font(.custom("Poppins-SemiBold", size: 8))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(2)

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LearnAlertStyle.indigo)
                        .background(Circle().fill(Color.black))
                        .padding(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .buttonStyle(.plain)
    }
}


// MARK: - PDF Thumbnail View

public struct PDFThumbnailView: View {
    public let document: PDFDocument
    public let pageIndex: Int
    public var size: CGSize = CGSize(width: 80, height: 110)

    @State private var thumbnail: UIImage?

    public init(document: PDFDocument, pageIndex: Int, size: CGSize = CGSize(width: 80, height: 110)) {
        self.document = document
        self.pageIndex = pageIndex
        self.size = size
    }

    public var body: some View {
        ZStack {
            Color.white.opacity(0.04)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .task(id: pageIndex) {
            if thumbnail == nil {
                await loadThumbnail()
            }
        }
    }

    private func loadThumbnail() async {
        let doc = self.document
        let idx = self.pageIndex
        let thumbSize = self.size
        let thumb = await Task.detached(priority: .background) { () -> UIImage? in
            guard let page = doc.page(at: idx) else { return nil }
            return page.thumbnail(of: thumbSize, for: .cropBox)
        }.value

        await MainActor.run {
            self.thumbnail = thumb
        }
    }
}
