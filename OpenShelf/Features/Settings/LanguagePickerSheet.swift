import SwiftUI

struct LanguagePickerSheet: View {
    @Binding var preferredLanguagesJSON: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var pendingCodes: Set<String> = []

    private var alreadySelected: Set<String> {
        Set(LanguageCode.decode(json: preferredLanguagesJSON))
    }

    private var availableCodes: [String] {
        let excluded = alreadySelected
        let unselected = LanguageCode.supported.filter { !excluded.contains($0.code) }
        if searchText.isEmpty { return unselected.map(\.code) }
        let query = searchText.lowercased()
        return unselected.filter { $0.name.lowercased().contains(query) }.map(\.code)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(availableCodes.enumerated()), id: \.element) { _, code in
                    Button {
                        togglePending(code)
                    } label: {
                        HStack {
                            Text(LanguageCode.displayName(for: code))
                                .foregroundStyle(.primary)
                            Spacer()
                            if pendingCodes.contains(code) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityHint("Adds this language to your Discover preferences")
                }
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Add Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitSelection()
                        dismiss()
                    }
                    .disabled(pendingCodes.isEmpty)
                }
            }
        }
    }

    private func togglePending(_ code: String) {
        if pendingCodes.contains(code) {
            pendingCodes.remove(code)
        } else {
            pendingCodes.insert(code)
        }
    }

    private func commitSelection() {
        var codes = LanguageCode.decode(json: preferredLanguagesJSON)
        for code in pendingCodes where !codes.contains(code) {
            codes.append(code)
        }
        preferredLanguagesJSON = LanguageCode.encode(codes)
    }
}
