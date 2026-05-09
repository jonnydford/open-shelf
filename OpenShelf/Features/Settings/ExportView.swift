import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .csv: "csv"
        case .json: "json"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv: .commaSeparatedText
        case .json: .json
        }
    }

    var description: String {
        switch self {
        case .csv: "Spreadsheet-compatible format with one row per book."
        case .json: "Full data dump including read history and metadata."
        }
    }
}

// MARK: - Export Document

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }

    let data: Data
    let contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Export View

struct ExportView: View {
    @Query private var books: [Book]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .csv
    @State private var isExporting = false
    @State private var exportDocument: ExportDocument?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(selectedFormat.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Export Format")
                }

                Section {
                    HStack {
                        Text("Books in library")
                        Spacer()
                        Text("\(books.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Summary")
                }

                Section {
                    if selectedFormat == .csv {
                        csvPreview
                    } else {
                        jsonPreview
                    }
                } header: {
                    Text("Included Fields")
                }

                Section {
                    Button {
                        generateExport()
                    } label: {
                        Label("Export \(selectedFormat.rawValue)", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(books.isEmpty)
                }
            }
            .navigationTitle("Export Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: selectedFormat.contentType,
                defaultFilename: "OpenShelf-Export.\(selectedFormat.fileExtension)"
            ) { result in
                switch result {
                case .success:
                    dismiss()
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Preview Content

    private var csvPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach([
                "Title", "Author", "ISBN13", "Shelf", "Rating",
                "Date Added", "Date Started", "Date Finished",
                "Current Page", "Notes", "Tags"
            ], id: \.self) { field in
                Label(field, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var jsonPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach([
                "All book metadata",
                "Read history entries",
                "Ratings and notes",
                "Shelf assignments",
                "Tags and subjects"
            ], id: \.self) { field in
                Label(field, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Generate Export

    private func generateExport() {
        let data: Data
        switch selectedFormat {
        case .csv:
            data = DataExporter.exportCSV(books: books)
        case .json:
            data = DataExporter.exportJSON(books: books)
        }

        exportDocument = ExportDocument(data: data, contentType: selectedFormat.contentType)
        isExporting = true
    }
}
