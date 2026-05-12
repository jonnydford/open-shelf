import SwiftUI
import SwiftData

struct ReadingListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSharingService.self) private var sharingService
    @Query(sort: \ReadingList.dateCreated, order: .reverse) private var lists: [ReadingList]

    @State private var showNewListAlert = false
    @State private var newListName = ""

    var body: some View {
        listContent
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

    // MARK: - List Content

    private var listContent: some View {
        List {
            Section("Smart Lists") {
                ForEach(SmartList.allCases) { smartList in
                    NavigationLink {
                        SmartListDetailView(smartList: smartList)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(smartList.name)
                                    .font(.headline)
                                Text(smartList.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } icon: {
                            Image(systemName: smartList.systemImage)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            if !lists.isEmpty {
                Section("My Lists") {
                    ForEach(lists) { list in
                        NavigationLink {
                            ReadingListDetailView(readingList: list)
                        } label: {
                            listRow(list)
                        }
                    }
                    .onDelete(perform: deleteLists)
                }
            }

            if CloudSharingService.isAvailable {
                Section {
                    NavigationLink {
                        SharedWithMeView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Shared with Me")
                                if !sharingService.sharedWithMe.isEmpty {
                                    Text(
                                        "\(sharingService.sharedWithMe.count) "
                                        + "\(sharingService.sharedWithMe.count == 1 ? "list" : "lists")"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "person.2.fill")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            guard CloudSharingService.isAvailable else { return }
            await sharingService.fetchSharedWithMe()
        }
    }

    private func listRow(_ list: ReadingList) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                Text("\(list.bookKeys.count) \(list.bookKeys.count == 1 ? "book" : "books")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Spacer()

            if list.ckRecordName != nil, CloudSharingService.isAvailable {
                Image(systemName: "icloud.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            let list = lists[index]
            if let recordName = list.ckRecordName {
                Task {
                    try? await sharingService.stopSharing(recordName: recordName)
                }
            }
            modelContext.delete(list)
        }
        try? modelContext.save()
    }
}
