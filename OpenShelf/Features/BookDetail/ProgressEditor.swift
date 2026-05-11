import SwiftUI

struct ProgressEditor: View {
    let book: Book
    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pageInput: String = ""
    @State private var chapterInput: String = ""
    @State private var percentageValue: Double = 0
    @State private var showFinishedAlert = false
    @State private var showRatingSheet = false
    @State private var finishRating: Double?
    @State private var validationError: String?
    @State private var useSlider = false
    @State private var showSaveToast = false
    @State private var showFinishCelebration = false

    private var isAudiobook: Bool {
        book.format == .audiobook
    }

    var body: some View {
        NavigationStack {
            Form {
                if isAudiobook {
                    audiobookContent
                } else {
                    pageContent
                }

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isAudiobook ? "Update Listening Progress" : "Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAudiobook {
                        if book.chapterCount != nil {
                            Button("Save") {
                                saveChapterProgress()
                            }
                            .disabled(chapterInput.isEmpty)
                        }
                    } else {
                        Button("Save") {
                            saveProgress()
                        }
                        .disabled(pageInput.isEmpty)
                    }
                }
            }
            .alert(isAudiobook ? "Finished Listening?" : "Finished Reading?", isPresented: $showFinishedAlert) {
                Button("Not Yet") {
                    if isAudiobook {
                        if let chapter = Int(chapterInput) {
                            repository.updateChapterProgress(book, chapter: chapter)
                        }
                    } else {
                        applyProgress(Int(pageInput) ?? 0)
                    }
                    dismiss()
                }
                Button("Yes, Finished!") {
                    showRatingSheet = true
                }
            } message: {
                Text(isAudiobook
                     ? "You've reached the last chapter. Mark this audiobook as finished?"
                     : "You've reached the last page. Mark this book as finished?")
            }
            .sheet(isPresented: $showRatingSheet) {
                ratingSheet
            }
            .onAppear {
                if isAudiobook {
                    if let chapter = book.currentChapter {
                        chapterInput = String(chapter)
                    }
                } else {
                    if let page = book.currentPage {
                        pageInput = String(page)
                    }
                    syncSliderFromPage()
                }
            }
        }
        .presentationDetents([.medium])
        .toast(isPresented: $showSaveToast, message: "Progress saved")
        .overlay {
            CelebrationOverlay(isPresented: $showFinishCelebration)
        }
    }

    // MARK: - Audiobook Content

    @ViewBuilder
    private var audiobookContent: some View {
        if book.chapterCount != nil {
            audiobookChapterProgressSection
            audiobookChapterInputSection
        } else {
            // Simple mode: just a finish button
            audiobookSimpleSection
        }
    }

    @ViewBuilder
    private var audiobookChapterProgressSection: some View {
        if let currentChapter = book.currentChapter, let chapterCount = book.chapterCount, chapterCount > 0 {
            Section("Current Progress") {
                let progress = min(Double(currentChapter) / Double(chapterCount), 1.0)
                let percentage = Int(progress * 100)

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .tint(.green)
                        .accessibilityLabel("Listening progress: \(percentage) percent")

                    Text("Chapter \(currentChapter) of \(chapterCount) (\(percentage)%)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var audiobookChapterInputSection: some View {
        Section("Chapter Number") {
            TextField("Enter current chapter", text: $chapterInput)
                .keyboardType(.numberPad)
                .accessibilityLabel("Current chapter number")
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                    }
                }

            if let chapterCount = book.chapterCount {
                Text("Total chapters: \(chapterCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audiobookSimpleSection: some View {
        Section {
            Button {
                showRatingSheet = true
            } label: {
                Label("Finished Listening", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        currentProgressSection
        inputSection

        if book.pageCount != nil {
            percentageSection
        }
    }

    // MARK: - Current Progress

    @ViewBuilder
    private var currentProgressSection: some View {
        if let currentPage = book.currentPage, let pageCount = book.pageCount, pageCount > 0 {
            Section("Current Progress") {
                let progress = min(Double(currentPage) / Double(pageCount), 1.0)
                let percentage = Int(progress * 100)

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .tint(.green)
                        .accessibilityLabel("Reading progress: \(percentage) percent")

                    Text("Page \(currentPage) of \(pageCount) (\(percentage)%)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let currentPage = book.currentPage {
            Section("Current Progress") {
                Text("Page \(currentPage)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        Section("Page Number") {
            TextField("Enter current page", text: $pageInput)
                .keyboardType(.numberPad)
                .accessibilityLabel("Current page number")
                .onChange(of: pageInput) { _, newValue in
                    syncSliderFromPage()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                    }
                }

            if let pageCount = book.pageCount {
                Text("Total pages: \(pageCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Percentage Slider

    private var percentageSection: some View {
        Section("Percentage") {
            VStack(spacing: 8) {
                Slider(value: $percentageValue, in: 0...100, step: 1) {
                    Text("Progress")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption2)
                }
                .onChange(of: percentageValue) { _, newValue in
                    syncPageFromSlider()
                }

                Text("\(Int(percentageValue))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Slider <-> Page Sync

    private func syncSliderFromPage() {
        guard let pageCount = book.pageCount, pageCount > 0,
              let page = Int(pageInput) else { return }
        let pct = min(Double(page) / Double(pageCount) * 100, 100)
        if abs(percentageValue - pct) > 0.5 {
            percentageValue = pct
        }
    }

    private func syncPageFromSlider() {
        guard let pageCount = book.pageCount, pageCount > 0 else { return }
        let page = Int(round(percentageValue / 100.0 * Double(pageCount)))
        let newPageStr = String(page)
        if pageInput != newPageStr {
            pageInput = newPageStr
        }
    }

    // MARK: - Rating Sheet

    private var ratingSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(isAudiobook ? "Rate This Audiobook" : "Rate This Book")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isAudiobook ? "How would you rate this audiobook?" : "How would you rate this book?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                RatingPicker(rating: $finishRating, mode: .interactive)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        finishBook(rating: nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Rating") {
                        finishBook(rating: finishRating)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func saveProgress() {
        guard let page = Int(pageInput), page > 0 else {
            validationError = "Please enter a valid page number."
            return
        }

        if let pageCount = book.pageCount, page > pageCount {
            validationError = "Page number can't exceed \(pageCount)."
            return
        }

        validationError = nil

        // Auto-finish check
        if let pageCount = book.pageCount, page >= pageCount {
            showFinishedAlert = true
        } else {
            applyProgress(page)
            showSaveToast = true
            dismissAfterDelay()
        }
    }

    private func saveChapterProgress() {
        guard let chapter = Int(chapterInput), chapter > 0 else {
            validationError = "Please enter a valid chapter number."
            return
        }

        if let chapterCount = book.chapterCount, chapter > chapterCount {
            validationError = "Chapter number can't exceed \(chapterCount)."
            return
        }

        validationError = nil

        // Auto-finish check
        if let chapterCount = book.chapterCount, chapter >= chapterCount {
            showFinishedAlert = true
        } else {
            repository.updateChapterProgress(book, chapter: chapter)
            showSaveToast = true
            dismissAfterDelay()
        }
    }

    private func applyProgress(_ page: Int) {
        repository.updateProgress(book, page: page)
    }

    private func dismissAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run { dismiss() }
        }
    }

    private func finishBook(rating: Double?) {
        if isAudiobook {
            if let chapter = Int(chapterInput) {
                repository.updateChapterProgress(book, chapter: chapter)
            }
        } else {
            if let page = Int(pageInput) {
                repository.updateProgress(book, page: page)
            }
        }

        // Create ReadEntry
        let entry = ReadEntry(
            book: book,
            startDate: book.dateStarted,
            finishDate: .now,
            rating: rating
        )
        modelContext.insert(entry)

        // Move to .read shelf
        repository.updateShelf(book, to: .read)

        // Set book-level rating to most recent read
        if let rating {
            repository.updateRating(book, rating: rating)
        }

        try? modelContext.save()
        showRatingSheet = false
        showFinishCelebration = true
        dismissAfterDelay()
    }
}
