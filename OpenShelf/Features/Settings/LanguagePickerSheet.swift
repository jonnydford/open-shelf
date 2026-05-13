import SwiftUI

struct LanguagePickerSheet: View {
    @Binding var preferredLanguagesJSON: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var selectedCodes: Set<String> {
        guard let data = preferredLanguagesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return ["eng"]
        }
        return Set(decoded)
    }

    private var availableLanguages: [(code: String, name: String)] {
        let selected = selectedCodes
        let unselected = LanguageCode.supported.filter { !selected.contains($0.code) }
        if searchText.isEmpty { return unselected }
        let query = searchText.lowercased()
        return unselected.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List(availableLanguages, id: \.code) { language in
                Button {
                    addLanguage(language.code)
                    dismiss()
                } label: {
                    Text(language.name)
                        .foregroundStyle(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Add Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addLanguage(_ code: String) {
        var codes: [String]
        if let data = preferredLanguagesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            codes = decoded
        } else {
            codes = ["eng"]
        }
        guard !codes.contains(code) else { return }
        codes.append(code)
        if let data = try? JSONEncoder().encode(codes),
           let json = String(data: data, encoding: .utf8) {
            preferredLanguagesJSON = json
        }
    }
}
