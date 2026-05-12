import SwiftUI
import SwiftData

struct SmartListDetailView: View {
    let smartList: SmartList

    @Query(sort: \Book.title) private var allBooks: [Book]

    private var matchingBooks: [Book] {
        allBooks.filter { smartList.matches($0) && !$0.isPrivate }
    }

    var body: some View {
        Group {
            if matchingBooks.isEmpty {
                ContentUnavailableView {
                    Label(smartList.name, systemImage: smartList.systemImage)
                } description: {
                    Text(emptyMessage)
                }
            } else {
                List {
                    ForEach(matchingBooks) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            BookRow(book: book)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(smartList.name)
    }

    private var emptyMessage: String {
        switch smartList {
        case .fiveStarBooks:
            "Rate a book 5 stars and it will appear here."
        case .favourites:
            "Favourite a book and it will appear here."
        case .readThisYear:
            "Books you finish this year will appear here."
        case .shortReads:
            "Books under 200 pages on your Want to Read shelf will appear here."
        case .unrated:
            "Books you've read without a rating will appear here."
        }
    }
}
