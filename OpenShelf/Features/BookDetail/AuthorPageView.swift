import SwiftUI

struct AuthorPageView: View {
    let authorName: String
    let authorKey: String?
    let authorBooks: [SearchResult]

    @Environment(BookRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var authorDetail: AuthorDetail?
    @State private var isLoading = true
    @State private var bioExpanded = false
    @State private var wikipediaURL: URL?
    @State private var resolvedAuthorKey: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let detail = authorDetail {
                        authorContent(detail)
                    } else {
                        fallbackContent
                    }

                    if !authorBooks.isEmpty {
                        moreByAuthorSection
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(authorName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadAuthorDetail() }
        }
    }

    // MARK: - Author Content

    private func authorContent(_ detail: AuthorDetail) -> some View {
        VStack(spacing: 16) {
            // Author photo
            if let photoID = detail.primaryPhotoID {
                AsyncImage(url: URL(string: "https://covers.openlibrary.org/a/id/\(photoID)-M.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    case .failure:
                        authorInitialsCircle
                    default:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    }
                }
                .padding(.top, 16)
            } else {
                authorInitialsCircle
                    .padding(.top, 16)
            }

            // Name
            Text(detail.name ?? authorName)
                .font(.title2)
                .fontWeight(.bold)

            // Life dates
            if let birth = detail.birthDate {
                let lifeDates = [birth, detail.deathDate].compactMap { $0 }.joined(separator: " \u{2013} ")
                Text(lifeDates)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Bio
            if let bio = detail.biographyText, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)

                    Text(bio)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(bioExpanded ? nil : 5)

                    if bio.count > 200 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                bioExpanded.toggle()
                            }
                        } label: {
                            Text(bioExpanded ? "Show Less" : "Show More")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

            // External links
            externalLinksSection(detail)
        }
    }

    private var authorInitialsCircle: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 120, height: 120)

            Text(String(authorName.prefix(1)).uppercased())
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var fallbackContent: some View {
        VStack(spacing: 12) {
            authorInitialsCircle
                .padding(.top, 16)

            Text(authorName)
                .font(.title2)
                .fontWeight(.bold)

            Text("Author details unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - External Links

    private func externalLinksSection(_ detail: AuthorDetail) -> some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            // Wikipedia
            if let url = wikipediaURL {
                externalLinkButton(title: "Wikipedia", icon: "globe", url: url)
            }

            // Official website
            if let links = detail.links {
                ForEach(validLinks(from: links), id: \.url) { link in
                    externalLinkButton(title: link.title, icon: "link", url: link.url)
                }
            }

            // Goodreads
            if let goodreadsID = detail.remoteIds?.goodreads,
               let url = URL(string: "https://www.goodreads.com/author/show/\(goodreadsID)") {
                externalLinkButton(title: "Goodreads", icon: "book.closed", url: url)
            }

            // StoryGraph
            if let storygraphID = detail.remoteIds?.storygraph,
               let url = URL(string: "https://app.thestorygraph.com/authors/\(storygraphID)") {
                externalLinkButton(title: "The StoryGraph", icon: "chart.bar.doc.horizontal", url: url)
            }
        }
    }

    private struct ValidLink: Hashable {
        let title: String
        let url: URL
    }

    private func validLinks(from links: [AuthorDetail.AuthorLink]) -> [ValidLink] {
        links.compactMap { link in
            guard let title = link.title,
                  let urlString = link.url,
                  let url = URL(string: urlString) else { return nil }
            return ValidLink(title: title, url: url)
        }
    }

    private func externalLinkButton(title: String, icon: String, url: URL) -> some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
    }

    // MARK: - More by Author

    private var moreByAuthorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal)

            Text("More by \(authorName)")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(authorBooks) { result in
                        VStack(spacing: 6) {
                            CoverImage(coverID: result.coverI, size: .small)
                                .frame(width: 80, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(result.title)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Data Loading

    private func loadAuthorDetail() async {
        isLoading = true
        defer { isLoading = false }

        // Resolve author key if not provided
        var key = authorKey
        if key == nil {
            // Try to extract from a work detail
            if let firstBook = authorBooks.first {
                do {
                    let workDetail = try await repository.fetchDetail(for: firstBook.key)
                    key = workDetail.primaryAuthorKey
                } catch {
                    // Non-critical
                }
            }
        }

        guard let key else { return }
        resolvedAuthorKey = key

        do {
            let detail = try await repository.fetchAuthorDetail(key: key)
            authorDetail = detail

            // Resolve Wikipedia URL if Wikidata ID is available
            if let wikidataID = detail.remoteIds?.wikidata {
                wikipediaURL = try? await repository.resolveWikipediaURL(wikidataID: wikidataID)
            }
        } catch {
            // Non-critical — show fallback
        }
    }
}
