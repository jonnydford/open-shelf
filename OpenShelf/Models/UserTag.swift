import Foundation
import SwiftData

@Model
final class UserTag {
    var name: String = ""
    var colour: String = "#007AFF"
    var sortOrder: Int = 0

    init(
        name: String,
        colour: String = "#007AFF",
        sortOrder: Int = 0
    ) {
        self.name = name
        self.colour = colour
        self.sortOrder = sortOrder
    }
}
