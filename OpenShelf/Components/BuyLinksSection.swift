import SwiftUI
import os

struct BuyLinksSection: View {
    let isbn: String?

    @Environment(BookRepository.self) private var repository
    @AppStorage("preferredBookshop") private var preferredBookshop: String = BookshopPreference.bookshopOrg.rawValue
    @AppStorage("preferredAudiobook") private var preferredAudiobook: String = AudiobookPreference.libroFm.rawValue
    @State private var appleBooksURL: URL?
    @State private var appleBooksPrice: String?

    private static let logger = Logger(subsystem: "com.forddevinc.OpenShelf", category: "BuyLinks")

    var body: some View {
        if let isbn {
            VStack(spacing: 12) {
                Divider()
                    .padding(.horizontal)

                buyButtons(isbn: isbn)
                appleBooksButton()
                listenButtons(isbn: isbn)
            }
            .task {
                await loadAppleBooksLink(isbn: isbn)
            }
        }
    }

    private func loadAppleBooksLink(isbn: String) async {
        do {
            if let ebook = try await repository.fetchAppleBooksLink(isbn: isbn) {
                appleBooksURL = URL(string: ebook.trackViewUrl)
                appleBooksPrice = ebook.formattedPrice
            }
        } catch {
            Self.logger.error("Failed to fetch Apple Books link: \(error.localizedDescription, privacy: .public)")
        }
    }

    @ViewBuilder
    private func appleBooksButton() -> some View {
        if let url = appleBooksURL {
            Button {
                UIApplication.shared.open(url)
            } label: {
                if let price = appleBooksPrice {
                    Label("Apple Books \(price)", systemImage: "book.fill")
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Apple Books", systemImage: "book.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func buyButtons(isbn: String) -> some View {
        let preference = BookshopPreference(rawValue: preferredBookshop) ?? .bookshopOrg

        if preference == .all {
            Menu {
                ForEach(BookshopService.allCases) { service in
                    if let url = service.url(for: isbn) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Text(service.rawValue)
                        }
                    }
                }
            } label: {
                Label("Buy from independent bookshop", systemImage: "cart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        } else {
            let service: BookshopService? = {
                switch preference {
                case .bookshopOrg: return .bookshopOrg
                case .hive: return .hive
                case .blackwells: return .blackwells
                case .all: return nil
                }
            }()

            if let service, let url = service.url(for: isbn) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("Buy from \(service.rawValue)", systemImage: "cart")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func listenButtons(isbn: String) -> some View {
        let preference = AudiobookPreference(rawValue: preferredAudiobook) ?? .libroFm

        if preference == .both {
            Menu {
                ForEach(AudiobookService.allCases) { service in
                    if let url = service.url(for: isbn) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Text(service.rawValue)
                        }
                    }
                }
            } label: {
                Label("Listen", systemImage: "headphones")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        } else {
            let service: AudiobookService? = {
                switch preference {
                case .libroFm: return .libroFm
                case .audibleUK: return .audibleUK
                case .both: return nil
                }
            }()

            if let service, let url = service.url(for: isbn) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("Listen on \(service.rawValue)", systemImage: "headphones")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
        }
    }
}
