import Foundation
import SwiftData
import BackgroundTasks

struct PendingNewBook: Codable, Sendable, Identifiable {
    let authorName: String
    let bookTitle: String
    let workKey: String
    var id: String { workKey }
}

enum AuthorCheckService: Sendable {

    static let taskIdentifier = "com.openshelf.authorcheck"

    // MARK: - Pending New Books Storage

    private static let pendingBooksKey = "pendingNewBooks"

    @MainActor
    static var pendingNewBooks: [PendingNewBook] {
        get {
            guard let data = UserDefaults.standard.data(forKey: pendingBooksKey),
                  let books = try? JSONDecoder().decode([PendingNewBook].self, from: data) else {
                return []
            }
            return books
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: pendingBooksKey)
            }
        }
    }

    @MainActor
    static func dismissPendingBook(workKey: String) {
        var books = pendingNewBooks
        books.removeAll { $0.workKey == workKey }
        pendingNewBooks = books
    }

    // MARK: - Background Task Registration

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // BGAppRefreshTask is not Sendable but is safe to use on MainActor
            // since the system only delivers one background task at a time.
            nonisolated(unsafe) let sendableTask = refreshTask
            Task { @MainActor in
                await handleAppRefresh(task: sendableTask)
            }
        }
    }

    static func scheduleBackgroundCheck() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Check Logic

    @MainActor
    private static func handleAppRefresh(task: BGAppRefreshTask) async {
        scheduleBackgroundCheck()

        let client = OpenLibraryClient()

        // Track the in-flight work so expiration can cancel it
        let workTask = Task { @MainActor in
            guard let container = try? SharedModelContainer.makeContainer() else {
                task.setTaskCompleted(success: false)
                return
            }

            let context = container.mainContext
            let descriptor = FetchDescriptor<FollowedAuthor>()
            guard let authors = try? context.fetch(descriptor), !authors.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }

            var newBooks = pendingNewBooks

            for author in authors.prefix(10) {
                try Task.checkCancellation()

                do {
                    if let authorKey = author.olAuthorKey {
                        // Use direct author works endpoint
                        let works = try await client.fetchAuthorWorks(authorKey: authorKey, limit: 5)
                        if let latest = works.entries.first {
                            if let lastKnown = author.lastKnownWorkKey, lastKnown != latest.key {
                                let alreadyPending = newBooks.contains { $0.workKey == latest.key }
                                if !alreadyPending {
                                    newBooks.append(PendingNewBook(
                                        authorName: author.authorName,
                                        bookTitle: latest.title,
                                        workKey: latest.key
                                    ))
                                }
                            }
                            author.lastKnownWorkKey = latest.key
                        }
                    } else {
                        // Fallback: search by author name when olAuthorKey is nil
                        let results = try await client.searchByAuthor(name: author.authorName)
                        if let latest = results.first {
                            if let lastKnown = author.lastKnownWorkKey, lastKnown != latest.key {
                                let alreadyPending = newBooks.contains { $0.workKey == latest.key }
                                if !alreadyPending {
                                    newBooks.append(PendingNewBook(
                                        authorName: author.authorName,
                                        bookTitle: latest.title,
                                        workKey: latest.key
                                    ))
                                }
                            }
                            author.lastKnownWorkKey = latest.key
                        }
                    }
                    author.lastCheckedDate = .now
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // Non-critical; continue with next author
                }
            }

            pendingNewBooks = newBooks
            try? context.save()

            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }

        // Await the work task so the function doesn't return prematurely
        _ = try? await workTask.value
    }
}
