import SwiftUI

struct ProgressEditor: View {
    let book: Book
    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pageInput: String = ""
    @State private var showFinishedAlert = false
    @State private var showRatingPrompt = false
    @State private var finishRating: Double?
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                currentProgressSection

                inputSection

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProgress()
                    }
                    .disabled(pageInput.isEmpty)
                }
            }
            .alert("Finished Reading?", isPresented: $showFinishedAlert) {
                Button("Not Yet") {
                    // Save progress without finishing
                    applyProgress(Int(pageInput) ?? 0)
                    dismiss()
                }
                Button("Yes, Finished!") {
                    showRatingPrompt = true
                }
            } message: {
                Text("You've reached the last page. Mark this book as finished?")
            }
            .alert("Rate This Book", isPresented: $showRatingPrompt) {
                Button("Skip") {
                    finishBook(rating: nil)
                }
                Button("Save Rating") {
                    finishBook(rating: finishRating)
                }
            } message: {
                Text("How would you rate this book?")
            }
            .overlay {
                if showRatingPrompt {
                    ratingOverlay
                }
            }
            .onAppear {
                if let page = book.currentPage {
                    pageInput = String(page)
                }
            }
        }
        .presentationDetents([.medium])
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

    // MARK: - Rating Overlay

    private var ratingOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                VStack(spacing: 16) {
                    Text("Rate This Book")
                        .font(.headline)
                    RatingPicker(rating: $finishRating, mode: .interactive)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .allowsHitTesting(true)
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
            dismiss()
        }
    }

    private func applyProgress(_ page: Int) {
        repository.updateProgress(book, page: page)
    }

    private func finishBook(rating: Double?) {
        if let page = Int(pageInput) {
            repository.updateProgress(book, page: page)
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
        dismiss()
    }
}
