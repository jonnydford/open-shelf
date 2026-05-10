import AppIntents

struct SelectBookIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Book"
    static let description: IntentDescription = "Choose which book to display in the widget."

    @Parameter(title: "Book")
    var book: BookEntity?
}
