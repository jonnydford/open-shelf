import SwiftUI

struct SocialSettingsSection: View {
    @Environment(BookRepository.self) private var repository
    @Environment(CloudSharingService.self) private var sharingService

    @AppStorage("socialEnabled") private var socialEnabled = false
    @AppStorage("shareCurrentlyReading") private var shareCurrentlyReading = true
    @AppStorage("shareRecentlyFinished") private var shareRecentlyFinished = true
    @AppStorage("shareRatings") private var shareRatings = true
    @AppStorage("shareGoalProgress") private var shareGoalProgress = true
    @AppStorage("shareNotes") private var shareNotes = false
    @AppStorage("shareProgress") private var shareProgress = false
    @AppStorage("socialDisplayName") private var socialDisplayName = ""

    @State private var showStopSharingAlert = false
    @State private var showPreview = false
    @State private var isPublishing = false

    var body: some View {
        Section("Social") {
            Toggle("Share my reading activity", isOn: $socialEnabled)
                .onChange(of: socialEnabled) { _, enabled in
                    if enabled {
                        if socialDisplayName.isEmpty {
                            fetchiCloudName()
                        }
                        publishShelf()
                    } else {
                        showStopSharingAlert = true
                    }
                }

            if socialEnabled {
                subToggles
                displayNameField
                actions
            }
        }
        .alert("Stop Sharing?", isPresented: $showStopSharingAlert) {
            Button("Cancel", role: .cancel) {
                socialEnabled = true
            }
            Button("Stop Sharing", role: .destructive) {
                unpublishShelf()
            }
        } message: {
            Text("This will remove your public shelf. Friends who follow you will no longer see your activity.")
        }
        .sheet(isPresented: $showPreview) {
            PublicShelfPreviewSheet(snapshot: buildSnapshot())
        }
        .task {
            if socialEnabled {
                await sharingService.fetchPublicShelfURL()
            }
        }
    }

    // MARK: - Sub-toggles

    private var subToggles: some View {
        Group {
            Toggle("Currently Reading", isOn: $shareCurrentlyReading)
                .onChange(of: shareCurrentlyReading) { _, _ in publishShelf() }

            Toggle("Recently Finished", isOn: $shareRecentlyFinished)
                .onChange(of: shareRecentlyFinished) { _, _ in publishShelf() }

            Toggle("Ratings", isOn: $shareRatings)
                .onChange(of: shareRatings) { _, _ in publishShelf() }

            Toggle("Reading Goal Progress", isOn: $shareGoalProgress)
                .onChange(of: shareGoalProgress) { _, _ in publishShelf() }

            Toggle("Notes & Reviews", isOn: $shareNotes)
                .onChange(of: shareNotes) { _, _ in publishShelf() }

            Toggle("Page & Chapter Progress", isOn: $shareProgress)
                .onChange(of: shareProgress) { _, _ in publishShelf() }

            privacyNotes
        }
    }

    private var privacyNotes: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Private books are never shared", systemImage: "lock.fill")
            Label("Your data stays in your iCloud account", systemImage: "icloud.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    // MARK: - Display Name

    private var displayNameField: some View {
        HStack {
            Text("Display Name")
            Spacer()
            TextField("Your name", text: $socialDisplayName)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
                .onSubmit { publishShelf() }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        Group {
            if let url = sharingService.publicShelfShareURL {
                ShareLink(
                    item: url,
                    subject: Text("\(resolvedDisplayName)'s Shelf"),
                    message: Text("Follow my reading on Open Shelf")
                ) {
                    Label("Share My Shelf Link", systemImage: "square.and.arrow.up")
                }

                let count = sharingService.publicShelfFollowerCount
                if count > 0 {
                    Label(
                        count == 1 ? "1 follower" : "\(count) followers",
                        systemImage: "person.2"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            Button {
                showPreview = true
            } label: {
                Label("Preview My Public Shelf", systemImage: "eye")
            }

            if isPublishing {
                HStack {
                    Text("Publishing…")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Helpers

    private var resolvedDisplayName: String {
        socialDisplayName.isEmpty ? "Reader" : socialDisplayName
    }

    private var visibilityFlags: PublicShelfSnapshot.VisibilityFlags {
        PublicShelfSnapshot.VisibilityFlags(
            currentlyReading: shareCurrentlyReading,
            recentlyFinished: shareRecentlyFinished,
            ratings: shareRatings,
            goalProgress: shareGoalProgress,
            notes: shareNotes,
            progress: shareProgress
        )
    }

    private func buildSnapshot() -> PublicShelfSnapshot {
        repository.buildPublicShelfSnapshot(
            displayName: resolvedDisplayName,
            flags: visibilityFlags
        )
    }

    private func publishShelf() {
        isPublishing = true
        Task {
            let snapshot = buildSnapshot()
            try? await sharingService.updatePublicShelf(snapshot: snapshot)
            isPublishing = false
        }
    }

    private func unpublishShelf() {
        Task {
            try? await sharingService.unpublishPublicShelf()
        }
        shareCurrentlyReading = true
        shareRecentlyFinished = true
        shareRatings = true
        shareGoalProgress = true
        shareNotes = false
        shareProgress = false
    }

    private func fetchiCloudName() {
        Task {
            if let name = await sharingService.fetchUserDisplayName() {
                socialDisplayName = name
            }
        }
    }
}

// MARK: - Preview Sheet

struct PublicShelfPreviewSheet: View {
    let snapshot: PublicShelfSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !snapshot.currentlyReading.isEmpty {
                    Section("Currently Reading") {
                        ForEach(snapshot.currentlyReading) { book in
                            bookRow(book)
                        }
                    }
                }

                if !snapshot.recentlyFinished.isEmpty {
                    Section("Recently Finished") {
                        ForEach(snapshot.recentlyFinished) { book in
                            bookRow(book)
                        }
                    }
                }

                if let goal = snapshot.goalProgress {
                    Section("Reading Goal") {
                        Text(goal)
                            .font(.headline)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("This is what friends will see", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label("Private books are never shown", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(snapshot.displayName)'s Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func bookRow(_ book: PublicBookEntry) -> some View {
        HStack(spacing: 12) {
            CoverImage(coverID: book.coverImageID, size: .small)
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(book.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let rating = book.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                if let note = book.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
