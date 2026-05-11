import SwiftUI
import WidgetKit

@main
struct OpenShelfWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrentlyReadingWidget()
        CurrentlyReadingLargeWidget()
        ReadingGoalWidget()
        ReadingStreakWidget()
        ReadingSessionLiveActivity()
    }
}
