import SwiftUI
import PhotosUI

struct ManualEntryView: View {
    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let prefillISBN: String?

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
    @State private var showCamera = false
    @State private var isFetchingCover = false
    @State private var validationError: String?
    @State private var selectedFormat: BookFormat = .book
    @State private var narrator = ""
    @State private var durationHoursText = ""
    @State private var durationMinutesText = ""
    @State private var chapterCountText = ""

    init(prefillISBN: String? = nil) {
        self.prefillISBN = prefillISBN
        _isbn = State(initialValue: prefillISBN ?? "")
    }

    @ScaledMetric(relativeTo: .body) private var coverPreviewWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .body) private var coverPreviewHeight: CGFloat = 90

    var body: some View {
        NavigationStack {
            Form {
                requiredSection
                formatPickerSection
                optionalSection
                if selectedFormat == .audiobook {
                    audiobookSection
                }
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

    // MARK: - Format Picker

    private var formatPickerSection: some View {
        Section("Format") {
            Picker("Format", selection: $selectedFormat) {
                ForEach(BookFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Audiobook Fields

    private var audiobookSection: some View {
        Section("Audiobook Details") {
            TextField("Narrator", text: $narrator)
                .textContentType(.name)
                .accessibilityLabel("Narrator name")

            HStack {
                TextField("Hours", text: $durationHoursText)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("Duration hours")
                Text("h")
                    .foregroundStyle(.secondary)
                TextField("Minutes", text: $durationMinutesText)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("Duration minutes")
                Text("m")
                    .foregroundStyle(.secondary)
            }

            TextField("Number of chapters", text: $chapterCountText)
                .keyboardType(.numberPad)
                .accessibilityLabel("Chapter count")
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
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverPreviewWidth, height: coverPreviewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose from Library", systemImage: "photo")
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            if !isbn.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    Task {
                        await fetchCoverByISBN()
                    }
                } label: {
                    if isFetchingCover {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching...")
                        }
                    } else {
                        Label("Search by ISBN", systemImage: "magnifyingglass")
                    }
                }
                .disabled(isFetchingCover)
            }

            if hasCoverImage {
                Button("Remove", role: .destructive) {
                    selectedPhotoItem = nil
                    coverImageData = nil
                    coverImage = nil
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadPhoto(from: newItem)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    coverImageData = data
                    coverImage = image
                }
            }
            .ignoresSafeArea()
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

    private func fetchCoverByISBN() async {
        let trimmedISBN = isbn.trimmingCharacters(in: .whitespaces)
        guard !trimmedISBN.isEmpty else { return }

        isFetchingCover = true
        defer { isFetchingCover = false }

        let urlString = "https://covers.openlibrary.org/b/isbn/\(trimmedISBN)-L.jpg"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count > 1000, // OL returns a tiny 1-pixel placeholder for missing covers
                  let image = UIImage(data: data) else { return }

            coverImageData = data
            coverImage = image
        } catch {
            // Non-critical — user can still pick from library or camera
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

        // Audiobook metadata
        let trimmedNarrator = narrator.trimmingCharacters(in: .whitespaces)
        let narratorValue: String? = (selectedFormat == .audiobook && !trimmedNarrator.isEmpty) ? trimmedNarrator : nil
        let durationMinutes: Int? = {
            guard selectedFormat == .audiobook else { return nil }
            let hours = Int(durationHoursText.trimmingCharacters(in: .whitespaces)) ?? 0
            let mins = Int(durationMinutesText.trimmingCharacters(in: .whitespaces)) ?? 0
            let total = hours * 60 + mins
            return total > 0 ? total : nil
        }()
        let chapterCount: Int? = {
            guard selectedFormat == .audiobook else { return nil }
            return Int(chapterCountText.trimmingCharacters(in: .whitespaces))
        }()

        let book = Book(
            olWorkKey: manualKey,
            isbn13: trimmedISBN.count == 13 ? trimmedISBN : nil,
            isbn10: trimmedISBN.count == 10 ? trimmedISBN : nil,
            title: trimmedTitle,
            authorName: trimmedAuthor,
            pageCount: pageCount,
            subjects: subjects,
            shelf: selectedShelf,
            dateAdded: .now,
            format: selectedFormat,
            narrator: narratorValue,
            durationMinutes: durationMinutes,
            chapterCount: chapterCount
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

        if let coverImageData {
            repository.imageCache.saveLocalCover(coverImageData, for: manualKey)
        }

        try? modelContext.save()
        dismiss()
    }

}
