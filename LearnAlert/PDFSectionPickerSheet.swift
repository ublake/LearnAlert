import SwiftUI
import PDFKit

public struct PDFSectionPickerSheet: View {
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
    @State private var rangeStart: Int = 1
    @State private var rangeEnd: Int = 1
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showHiddenSections = false

    public enum PickerTab: String, CaseIterable {
        case sections = "Sections"
        case customRange = "Custom Range"
        case visualGrid = "Page Thumbnails"
    }

    private var visibleSections: [PDFSectionItem] {
        if showHiddenSections {
            return sections
        }
        let filtered = sections.filter { section in
            section.kind != .frontMatter && !section.isContentless
        }
        return filtered.isEmpty ? sections : filtered
    }

    private var hiddenSectionsCount: Int {
        sections.count - visibleSections.count
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
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LearnAlertStyle.courseCanvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header document info
                    documentHeaderView

                    // Mode switch
                    Picker("Mode", selection: $selectedTab) {
                        if !visibleSections.isEmpty {
                            Text(PickerTab.sections.rawValue).tag(PickerTab.sections)
                        }
                        Text(PickerTab.customRange.rawValue).tag(PickerTab.customRange)
                        Text(PickerTab.visualGrid.rawValue).tag(PickerTab.visualGrid)
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
                            case .customRange:
                                customRangePickerView
                            case .visualGrid:
                                visualThumbnailGridView
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
                    .foregroundStyle(Color.white.opacity(0.8))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !selectedPageIndices.isEmpty {
                        Button("Clear All") {
                            clearAllSelections()
                        }
                        .font(.custom("Poppins-Medium", size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
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
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.red.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(sourceName)
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(document.pageCount) Pages")
                        .font(.custom("Poppins-Medium", size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))

                    Text("•")
                        .foregroundStyle(Color.white.opacity(0.3))

                    Text(detectionMethod.rawValue)
                        .font(.custom("Poppins-Medium", size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundStyle(LearnAlertStyle.indigo)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Sections List View with Horizontal Thumbnail Preview

    private var sectionsListView: some View {
        VStack(spacing: 12) {
            ForEach(visibleSections) { section in
                let isSelected = selectedSectionIDs.contains(section.id)
                VStack(alignment: .leading, spacing: 10) {
                    // Tap header row to toggle section
                    Button {
                        toggleSection(section)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.3))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(section.title)
                                        .font(.custom("Poppins-SemiBold", size: 14))
                                        .foregroundStyle(Color.white)
                                        .multilineTextAlignment(.leading)

                                    Spacer()

                                    kindBadge(for: section.kind)
                                }

                                HStack(spacing: 6) {
                                    Text("Pages \(section.startPageIndex + 1)–\(section.endPageIndex + 1)")
                                        .font(.custom("Poppins-Regular", size: 12))
                                        .foregroundStyle(Color.white.opacity(0.65))

                                    Text("•")
                                        .foregroundStyle(Color.white.opacity(0.3))

                                    Text("\(section.pageCount) \(section.pageCount == 1 ? "page" : "pages")")
                                        .font(.custom("Poppins-Medium", size: 12))
                                        .foregroundStyle(section.pageCount > maxPageLimit ? Color.orange : Color.white.opacity(0.65))
                                }

                                if let summary = section.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.custom("Poppins-Regular", size: 12))
                                        .foregroundStyle(Color.white.opacity(0.55))
                                        .padding(.top, 1)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Horizontal Thumbnail Scroll for each page in this section
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(section.startPageIndex...section.endPageIndex, id: \.self) { pageIndex in
                                let pageSelected = selectedPageIndices.contains(pageIndex)
                                Button {
                                    toggleSinglePage(pageIndex)
                                } label: {
                                    VStack(spacing: 4) {
                                        PDFThumbnailView(
                                            document: document,
                                            pageIndex: pageIndex,
                                            size: CGSize(width: 52, height: 72)
                                        )
                                        .frame(width: 52, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(pageSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.12), lineWidth: pageSelected ? 2 : 1)
                                        )

                                        Text("p. \(pageIndex + 1)")
                                            .font(.custom("Poppins-Medium", size: 10))
                                            .foregroundStyle(pageSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? LearnAlertStyle.indigo.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                )
            }

            // Hidden Front-Matter / Contentless Sections Notice
            if hiddenSectionsCount > 0 && !showHiddenSections {
                Button {
                    withAnimation(.snappy) {
                        showHiddenSections = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 12))
                        Text("\(hiddenSectionsCount) front-matter / blank sections auto-hidden • Tap to show")
                            .font(.custom("Poppins-Regular", size: 12))
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.vertical, 8)
                }
            } else if showHiddenSections && hiddenSectionsCount > 0 {
                Button {
                    withAnimation(.snappy) {
                        showHiddenSections = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                        Text("Hide front-matter / blank sections")
                            .font(.custom("Poppins-Regular", size: 12))
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.vertical, 8)
                }
            }
        }
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

    // MARK: - Custom Range Picker View

    private var customRangePickerView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Page Range (Max 20 Pages)")
                    .font(.custom("Poppins-SemiBold", size: 15))
                    .foregroundStyle(Color.white)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From Page")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Stepper(value: $rangeStart, in: 1...document.pageCount) {
                            Text("Page \(rangeStart)")
                                .font(.custom("Poppins-SemiBold", size: 15))
                                .foregroundStyle(Color.white)
                        }
                        .onChange(of: rangeStart) { _, newValue in
                            updatePagesFromCustomRange(start: newValue, end: max(newValue, rangeEnd))
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("To Page")
                            .font(.custom("Poppins-Regular", size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Stepper(value: $rangeEnd, in: 1...document.pageCount) {
                            Text("Page \(rangeEnd)")
                                .font(.custom("Poppins-SemiBold", size: 15))
                                .foregroundStyle(Color.white)
                        }
                        .onChange(of: rangeEnd) { _, newValue in
                            updatePagesFromCustomRange(start: min(rangeStart, newValue), end: newValue)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Quick shortcuts (capped at 20 pages max)
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Selections (Max 20 Pages)")
                    .font(.custom("Poppins-Medium", size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))

                HStack(spacing: 8) {
                    quickSelectButton(title: "First 5 Pages", count: 5)
                    quickSelectButton(title: "First 10 Pages", count: 10)
                    quickSelectButton(title: "First 15 Pages", count: 15)
                    quickSelectButton(title: "First 20 Pages", count: 20)
                }
            }
        }
    }

    private func quickSelectButton(title: String, count: Int) -> some View {
        Button {
            rangeStart = 1
            rangeEnd = min(count, document.pageCount)
            updatePagesFromCustomRange(start: rangeStart, end: rangeEnd)
        } label: {
            Text(title)
                .font(.custom("Poppins-Medium", size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    // MARK: - Visual Grid View (using page.thumbnail(of:for:))

    private var visualThumbnailGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 12)], spacing: 12) {
            ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                let isSelected = selectedPageIndices.contains(pageIndex)
                Button {
                    toggleSinglePage(pageIndex)
                } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
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

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(LearnAlertStyle.indigo)
                                    .background(Circle().fill(Color.black))
                                    .padding(4)
                            }
                        }

                        Text("p. \(pageIndex + 1)")
                            .font(.custom("Poppins-Medium", size: 11))
                            .foregroundStyle(isSelected ? LearnAlertStyle.indigo : Color.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Footer & Live Selection (Removed inaccurate card estimate)

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
                            .foregroundStyle(Color.white)

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
                        .foregroundStyle(Color.white.opacity(0.6))
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
        // By default, deselect everything as requested!
        selectedSectionIDs = []
        selectedPageIndices = []
        rangeStart = 1
        rangeEnd = min(document.pageCount, 1)
    }

    private func clearAllSelections() {
        errorMessage = nil
        selectedSectionIDs.removeAll()
        selectedPageIndices.removeAll()
        rangeStart = 1
        rangeEnd = 1
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
        syncRangeFromPageIndices()
    }

    private func updatePagesFromCustomRange(start: Int, end: Int) {
        errorMessage = nil
        let s = max(0, min(start, end) - 1)
        var e = min(document.pageCount - 1, max(start, end) - 1)
        let count = e - s + 1
        if count > maxPageLimit {
            errorMessage = "Maximum \(maxPageLimit) pages allowed. Clamped to 20 pages."
            e = s + maxPageLimit - 1
            rangeEnd = e + 1
        }
        selectedPageIndices = Set(s...e)
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
        syncRangeFromPageIndices()
    }

    private func syncSectionsFromPageIndices() {
        var activeIDs = Set<String>()
        for section in visibleSections {
            let sectionPages = Set(section.startPageIndex...section.endPageIndex)
            if !sectionPages.isEmpty && sectionPages.isSubset(of: selectedPageIndices) {
                activeIDs.insert(section.id)
            }
        }
        selectedSectionIDs = activeIDs
    }

    private func syncRangeFromPageIndices() {
        guard !selectedPageIndices.isEmpty else { return }
        let sorted = selectedPageIndices.sorted()
        rangeStart = sorted.first! + 1
        rangeEnd = sorted.last! + 1
    }

    private func exportAndConfirmSubset() {
        guard !selectedPageIndices.isEmpty else { return }
        isExporting = true
        errorMessage = nil

        let baseName = (sourceName as NSString).deletingPathExtension
        let activeSections = sections.filter { selectedSectionIDs.contains($0.id) }

        let formattedSectionName: String
        let folderTitle: String?

        if activeSections.count == 1, let first = activeSections.first {
            formattedSectionName = "\(baseName) — \(first.title)"
            folderTitle = "\(first.title) (Pages \(first.startPageIndex + 1)–\(first.endPageIndex + 1))"
        } else if activeSections.count > 1 {
            formattedSectionName = "\(baseName) (\(activeSections.count) Modules, \(selectedPageIndices.count) Pages)"
            folderTitle = activeSections.map(\.title).joined(separator: ", ")
        } else {
            let sorted = selectedPageIndices.sorted()
            if sorted.count == 1 {
                formattedSectionName = "\(baseName) (Page \(sorted.first! + 1))"
                folderTitle = "Page \(sorted.first! + 1)"
            } else {
                formattedSectionName = "\(baseName) (Pages \(sorted.first! + 1)–\(sorted.last! + 1))"
                folderTitle = "Pages \(sorted.first! + 1)–\(sorted.last! + 1)"
            }
        }

        let doc = self.document
        let pagesToExport = self.selectedPageIndices

        Task.detached(priority: .userInitiated) {
            do {
                let subsetData = try PDFOutlineManager.createSubset(from: doc, selectedPageIndices: pagesToExport)
                await MainActor.run {
                    self.isExporting = false
                    self.onConfirm(subsetData, formattedSectionName, folderTitle)
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
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
