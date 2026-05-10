import CoreGraphics

enum ShareFormat: String, CaseIterable, Identifiable, Sendable {
    case story = "Story"
    case portrait = "Portrait"
    case square = "Square"

    var id: String { rawValue }

    var dimensions: (width: CGFloat, height: CGFloat) {
        switch self {
        case .story: return (1080, 1920)
        case .portrait: return (1080, 1350)
        case .square: return (1080, 1080)
        }
    }

    var aspectRatioLabel: String {
        switch self {
        case .story: return "9:16"
        case .portrait: return "4:5"
        case .square: return "1:1"
        }
    }
}
