import Foundation
import SwiftData

@Model
final class ReadingGoal {
    @Attribute(.unique) var year: Int
    var target: Int

    init(year: Int, target: Int) {
        self.year = year
        self.target = target
    }
}
