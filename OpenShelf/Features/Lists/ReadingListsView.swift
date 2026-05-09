import SwiftUI
import SwiftData

struct ReadingListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingList.dateCreated, order: .reverse) private var lists: [ReadingList]

    @State private var showNewListAlert = false
    @State private var newListName = ""

    var body: some View {
        Group {
            if lists.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Reading Lists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newListName = ""
                    showNewListAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New list")
            }
        }
        .alert("New Reading List", isPresented: $showNewListAlert) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                createList()
            }
            .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for your new reading list.")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Reading Lists", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Create a reading list to organise and share your favourite books.")
        } actions: {
            Button("Create a List") {
                newListName = ""
                showNewListAlert = true
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        List {
            ForEach(lists) { list in
                NavigationLink {
                    ReadingListDetailView(readingList: list)
                } label: {
                    listRow(list)
                }
            }
            .onDelete(perform: deleteLists)
        }
        .listStyle(.plain)
    }

    private func listRow(_ list: ReadingList) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.headline)
            Text("\(list.bookKeys.count) \(list.bookKeys.count == 1 ? "book" : "books")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func createList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let list = ReadingList(name: trimmedName)
        modelContext.insert(list)
        try? modelContext.save()
    }

    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lists[index])
        }
        try? modelContext.save()
    }
}
