import SwiftUI
import PhotosUI

struct ManualEntryView: View {
    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var pageCountText = ""
    @State private var isbn = ""
    @State private var selectedShelf: Shelf = .wantToRead
    @State private var subjectTags = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var coverImage: UIImage?
    @State private var isSaving = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                requiredSection
                optionalSection
                coverSection
                shelfSection
            }
            .navigationTitle("Add Book Manually")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(!title.isEmpty || !author.isEmpty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBook()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              author.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isSaving)
                }
            }
        }
    }

    // MARK: - Required Fields

    private var requiredSection: some View {
        Section {
            TextField("Title", text: $title)
                .textContentType(.none)
                .accessibilityLabel("Book title")

            TextField("Author", text: $author)
                .textContentType(.name)
                .accessibilityLabel("Author name")
        } header: {
            Text("Required")
        } footer: {
            if let validationError {
                Text(validationError)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Optional Fields

    private var optionalSection: some View {
        Section("Optional") {
            TextField("Page count", text: $pageCountText)
                .keyboardType(.numberPad)
                .accessibilityLabel("Page count")

            TextField("ISBN", text: $isbn)
                .keyboardType(.numberPad)
                .accessibilityLabel("ISBN number")

            TextField("Genres / subjects (comma-separated)", text: $subjectTags)
                .textContentType(.none)
                .accessibilityLabel("Genres or subjects, comma separated")
        }
    }

    // MARK: - Cover Section

    private var hasCoverImage: Bool {
        coverImage != nil
    }

    private var coverSection: some View {
        Section("Cover Image") {
            HStack {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                }

                let buttonLabel = hasCoverImage ? "Change Photo" : "Choose Photo"
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(buttonLabel, systemImage: "photo")
                }

                if hasCoverImage {
                    Button("Remove", role: .destructive) {
                        selectedPhotoItem = nil
                        coverImageData = nil
                        coverImage = nil
                    }
                    .font(.subheadline)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadPhoto(from: newItem)
                }
            }
        }
    }

    // MARK: - Shelf Section

    private var shelfSection: some View {
        Section("Add to Shelf") {
            Picker("Shelf", selection: $selectedShelf) {
                ForEach(Shelf.allCases, id: \.self) { shelf in
                    Label(shelf.displayName, systemImage: shelf.systemImage)
                        .tag(shelf)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                coverImageData = data
                coverImage = UIImage(data: data)
            }
        } catch {
            // Photo load failed; ignore silently
        }
    }

    private func saveBook() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespaces)

        guard !trimmedTitle.isEmpty else {
            validationError = "Title is required."
            return
        }
        guard !trimmedAuthor.isEmpty else {
            validationError = "Author is required."
            return
        }

        validationError = nil
        isSaving = true

        let pageCount = Int(pageCountText.trimmingCharacters(in: .whitespaces))

        let subjects: [String] = {
            let raw = subjectTags.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return [] }
            return raw.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }()

        let trimmedISBN = isbn.trimmingCharacters(in: .whitespaces)

        let manualKey = "manual-\(UUID().uuidString)"

        let book = Book(
            olWorkKey: manualKey,
            isbn13: trimmedISBN.count == 13 ? trimmedISBN : nil,
            isbn10: trimmedISBN.count == 10 ? trimmedISBN : nil,
            title: trimmedTitle,
            authorName: trimmedAuthor,
            pageCount: pageCount,
            subjects: subjects,
            shelf: selectedShelf,
            dateAdded: .now
        )

        // Set shelf-specific dates
        switch selectedShelf {
        case .reading:
            book.dateStarted = .now
        case .read:
            book.dateStarted = .now
            book.dateFinished = .now
        case .wantToRead, .dnf:
            break
        }

        modelContext.insert(book)

        // Save cover image to cache if provided
        if let coverImageData {
            saveCoverLocally(data: coverImageData, bookKey: manualKey)
        }

        try? modelContext.save()
        dismiss()
    }

    /// Save a user-provided cover image to Application Support (persistent, backed up).
    /// API-fetched covers stay in Caches (re-fetchable), but manual covers cannot be
    /// re-downloaded, so they must not be in a purgeable directory.
    private func saveCoverLocally(data: Data, bookKey: String) {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let coverDir = appSupportDir.appendingPathComponent("Covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: coverDir, withIntermediateDirectories: true)
        let fileURL = coverDir.appendingPathComponent("\(bookKey).jpg")
        try? data.write(to: fileURL, options: .atomic)
    }
}
