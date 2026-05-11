import SwiftUI

struct BuyLinksSection: View {
    let isbn: String?

    @AppStorage("preferredBookshop") private var preferredBookshop: String = BookshopPreference.bookshopOrg.rawValue
    @AppStorage("preferredAudiobook") private var preferredAudiobook: String = AudiobookPreference.libroFm.rawValue

    var body: some View {
        if let isbn {
            VStack(spacing: 12) {
                Divider()
                    .padding(.horizontal)

                buyButtons(isbn: isbn)
                listenButtons(isbn: isbn)
            }
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
