import SwiftUI

struct SettingsView: View {
    @State private var showImportView = false

    var body: some View {
        NavigationStack {
            List {
                importSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showImportView) {
                ImportView()
            }
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        Section("Import") {
            Button {
                showImportView = true
            } label: {
                Label("Import from Goodreads", systemImage: "square.and.arrow.down")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Privacy")
                Spacer()
                Text("All data stays on your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
