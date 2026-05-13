import Foundation
import SwiftData

@Model
final class ReadingGoal {
    var year: Int = 0
    var target: Int = 0

    init(year: Int, target: Int) {
        self.year = year
        self.target = target
    }
}
