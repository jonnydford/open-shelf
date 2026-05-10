import SwiftUI

struct NotesEditor: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: notesBinding)
                    .focused($isFocused)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isFocused = false
                                try? modelContext.save()
                            }
                        }
                    }

                if book.notes == nil || book.notes?.isEmpty == true {
                    Text("Add your thoughts...")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                // Auto-save on dismiss
                try? modelContext.save()
            }
        }
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { book.notes ?? "" },
            set: { book.notes = $0.isEmpty ? nil : $0 }
        )
    }
}
