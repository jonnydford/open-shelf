import Foundation

enum LanguageCode {
    static let supported: [(code: String, name: String)] = [
        ("eng", "English"),
        ("spa", "Spanish"),
        ("fre", "French"),
        ("ger", "German"),
        ("por", "Portuguese"),
        ("ita", "Italian"),
        ("dut", "Dutch"),
        ("jpn", "Japanese"),
        ("chi", "Chinese"),
        ("kor", "Korean"),
        ("rus", "Russian"),
        ("ara", "Arabic"),
        ("hin", "Hindi"),
        ("swe", "Swedish"),
        ("nor", "Norwegian"),
        ("dan", "Danish"),
        ("fin", "Finnish"),
        ("pol", "Polish"),
        ("tur", "Turkish"),
        ("cat", "Catalan"),
        ("cze", "Czech"),
        ("gre", "Greek"),
        ("heb", "Hebrew"),
        ("hun", "Hungarian"),
        ("ind", "Indonesian"),
        ("may", "Malay"),
        ("per", "Persian"),
        ("rum", "Romanian"),
        ("tha", "Thai"),
        ("ukr", "Ukrainian"),
        ("vie", "Vietnamese"),
        ("wel", "Welsh"),
        ("gle", "Irish"),
        ("gla", "Scottish Gaelic"),
    ]

    private static let codeToName: [String: String] = Dictionary(
        uniqueKeysWithValues: supported.map { ($0.code, $0.name) }
    )

    static func displayName(for code: String) -> String {
        codeToName[code] ?? code
    }
}
