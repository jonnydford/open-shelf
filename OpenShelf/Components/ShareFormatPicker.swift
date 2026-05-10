import SwiftUI

struct ShareFormatPicker: View {
    @Binding var selectedFormat: ShareFormat

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ShareFormat.allCases) { format in
                Button {
                    selectedFormat = format
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(
                                selectedFormat == format ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: 2
                            )
                            .fill(selectedFormat == format ? Color.accentColor.opacity(0.1) : Color.clear)
                            .aspectRatio(aspectSize(for: format), contentMode: .fit)
                            .frame(height: 60)

                        Text(format.rawValue)
                            .font(.caption2.bold())
                            .foregroundStyle(selectedFormat == format ? Color.accentColor : .secondary)

                        Text(format.aspectRatioLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(format.rawValue) format, \(format.aspectRatioLabel)")
            }
        }
    }

    private func aspectSize(for format: ShareFormat) -> CGSize {
        let dims = format.dimensions
        return CGSize(width: dims.width, height: dims.height)
    }
}
