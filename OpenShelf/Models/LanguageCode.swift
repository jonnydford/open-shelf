import Foundation

enum LanguageCode {
    static let supported: [(code: String, name: String, nativeName: String)] = [
        ("eng", "English", "English"),
        ("spa", "Spanish", "Español"),
        ("fre", "French", "Français"),
        ("ger", "German", "Deutsch"),
        ("por", "Portuguese", "Português"),
        ("ita", "Italian", "Italiano"),
        ("dut", "Dutch", "Nederlands"),
        ("jpn", "Japanese", "日本語"),
        ("chi", "Chinese", "中文"),
        ("kor", "Korean", "한국어"),
        ("rus", "Russian", "Русский"),
        ("ara", "Arabic", "العربية"),
        ("hin", "Hindi", "हिन्दी"),
        ("swe", "Swedish", "Svenska"),
        ("nor", "Norwegian", "Norsk"),
        ("dan", "Danish", "Dansk"),
        ("fin", "Finnish", "Suomi"),
        ("pol", "Polish", "Polski"),
        ("tur", "Turkish", "Türkçe"),
        ("cat", "Catalan", "Català"),
        ("cze", "Czech", "Čeština"),
        ("gre", "Greek", "Ελληνικά"),
        ("heb", "Hebrew", "עברית"),
        ("hun", "Hungarian", "Magyar"),
        ("ind", "Indonesian", "Bahasa Indonesia"),
        ("may", "Malay", "Bahasa Melayu"),
        ("per", "Persian", "فارسی"),
        ("rum", "Romanian", "Română"),
        ("tha", "Thai", "ไทย"),
        ("ukr", "Ukrainian", "Українська"),
        ("vie", "Vietnamese", "Tiếng Việt"),
        ("wel", "Welsh", "Cymraeg"),
        ("gle", "Irish", "Gaeilge"),
        ("gla", "Scottish Gaelic", "Gàidhlig"),
    ]

    private static let codeToName: [String: String] = Dictionary(
        uniqueKeysWithValues: supported.map { ($0.code, $0.name) }
    )

    static func displayName(for code: String) -> String {
        codeToName[code] ?? code
    }

    static func decode(json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data),
              !decoded.isEmpty else {
            return ["eng"]
        }
        return decoded
    }

    static func encode(_ codes: [String]) -> String {
        let safeCodes = codes.isEmpty ? ["eng"] : codes
        guard let data = try? JSONEncoder().encode(safeCodes),
              let json = String(data: data, encoding: .utf8) else {
            return "[\"eng\"]"
        }
        return json
    }
}
