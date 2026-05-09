import Foundation
import SwiftData

@Model
final class UserTag {
    var name: String
    var colour: String
    var sortOrder: Int

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
