import SwiftUI
import VisionKit
import AVFoundation

// MARK: - Scanned Book Result

struct ScannedBookResult: Identifiable {
    let id = UUID()
    let searchResult: SearchResult
    let workDetail: WorkDetail?
}

// MARK: - Barcode Scanner View

struct BarcodeScannerView: View {
    @Environment(BookRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var booksAdded = 0
    @State private var isProcessing = false
    @State private var scannedISBN: String?
    @State private var scannedBook: ScannedBookResult?
    @State private var errorMessage: String?
    @State private var processedISBNs: Set<String> = []
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraPermission == .authorized {
                    scannerContent
                } else if cameraPermission == .denied || cameraPermission == .restricted {
                    permissionDeniedView
                } else {
                    requestingPermissionView
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if booksAdded > 0 {
                        Text("\(booksAdded) added")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }
            }
            .task {
                await checkCameraPermission()
            }
            .sheet(item: $scannedBook) { result in
                BookDetailSheet(searchResult: result.searchResult) {
                    booksAdded += 1
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView(prefillISBN: scannedISBN)
            }
        }
    }

    // MARK: - Scanner Content

    private var scannerContent: some View {
        ZStack {
            DataScannerRepresentable(
                onBarcodeScanned: { isbn in
                    handleScannedISBN(isbn)
                }
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                if isProcessing {
                    processingOverlay
                }

                if let errorMessage {
                    errorOverlay(message: errorMessage)
                }

                Spacer()
            }
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Looking up book...")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Error Overlay

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button("Add Manually") {
                errorMessage = nil
                showManualEntry = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.blue, in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.bottom, 40)
    }

    // MARK: - Permission Views

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Required", systemImage: "camera.fill")
        } description: {
            Text("Open Shelf needs camera access to scan book barcodes. Your camera feed is never recorded or stored.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var requestingPermissionView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Requesting camera access...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = status

        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermission = granted ? .authorized : .denied
        }
    }

    private func handleScannedISBN(_ isbn: String) {
        // Skip if already processing or already scanned this ISBN
        guard !isProcessing, !processedISBNs.contains(isbn) else { return }

        processedISBNs.insert(isbn)
        scannedISBN = isbn
        errorMessage = nil

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        Task {
            await lookupISBN(isbn)
        }
    }

    private func lookupISBN(_ isbn: String) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let edition = try await repository.lookupISBN(isbn) else {
                errorMessage = "ISBN \(isbn) not found in Open Library."
                return
            }

            // Build a SearchResult from the edition detail
            let searchResult = SearchResult(
                key: edition.workKey ?? edition.key,
                title: edition.title,
                authorName: nil,
                firstPublishYear: nil,
                numberOfPagesMedian: edition.numberOfPages,
                coverI: edition.primaryCoverID,
                editionCount: nil,
                isbn: (edition.isbn13 ?? []) + (edition.isbn10 ?? []),
                subject: nil,
                idGoodreads: nil,
                ratingsAverage: nil,
                ratingsCount: nil,
                readinglogCount: nil,
                wantToReadCount: nil,
                currentlyReadingCount: nil,
                alreadyReadCount: nil,
                language: nil
            )

            // Try to fetch work detail for richer data
            var workDetail: WorkDetail?
            if let workKey = edition.workKey {
                workDetail = try? await repository.fetchDetail(for: workKey)
            }

            await MainActor.run {
                scannedBook = ScannedBookResult(
                    searchResult: searchResult,
                    workDetail: workDetail
                )
            }
        } catch {
            errorMessage = "Could not look up book. Check your connection."
        }
    }
}

// MARK: - DataScanner UIViewControllerRepresentable

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if !controller.isScanning {
            try? controller.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcodeScanned: (String) -> Void

        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item {
                    if let isbn = barcode.payloadStringValue {
                        let callback = onBarcodeScanned
                        Task { @MainActor in
                            callback(isbn)
                        }
                    }
                }
            }
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        if controller.isScanning {
            controller.stopScanning()
        }
    }
}

// MARK: - Camera Availability Check

extension BarcodeScannerView {
    /// Returns true if the device supports DataScannerViewController (has a camera).
    static var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
}
