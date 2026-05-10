import SwiftUI

struct LibraryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("preferredLibraryService") private var preferredLibraryService: String = LibraryService.libby.rawValue
    @AppStorage("spydusCloudSlug") private var spydusCloudSlug: String = ""
    @AppStorage("kohaLibraryDomain") private var kohaLibraryDomain: String = ""

    @State private var searchText = ""
    @State private var authorities: [UKLibraryAuthority] = []

    private var filteredAuthorities: [UKLibraryAuthority] {
        if searchText.isEmpty {
            return authorities
        }
        let query = searchText.lowercased()
        return authorities.filter {
            $0.name.lowercased().contains(query) || $0.region.lowercased().contains(query)
        }
    }

    private var groupedAuthorities: [(String, [UKLibraryAuthority])] {
        let grouped = Dictionary(grouping: filteredAuthorities, by: \.region)
        return grouped
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedAuthorities, id: \.0) { region, items in
                    Section(region) {
                        ForEach(items) { authority in
                            Button {
                                selectAuthority(authority)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(authority.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(authority.libraryService.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .accessibilityLabel("\(authority.name), \(authority.region), \(authority.libraryService.rawValue)")
                        }
                    }
                }

                Section {
                    Button {
                        preferredLibraryService = LibraryService.custom.rawValue
                        dismiss()
                    } label: {
                        HStack {
                            Label("My library isn't listed", systemImage: "questionmark.circle")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Custom")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by council or region")
            .navigationTitle("Find Your Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                authorities = UKLibraryAuthorityLoader.load()
            }
        }
    }

    private func selectAuthority(_ authority: UKLibraryAuthority) {
        preferredLibraryService = authority.libraryService.rawValue

        switch authority.libraryService {
        case .spydusCloud:
            spydusCloudSlug = authority.slug ?? ""
        case .koha:
            kohaLibraryDomain = authority.domain ?? ""
        default:
            break
        }

        dismiss()
    }
}
