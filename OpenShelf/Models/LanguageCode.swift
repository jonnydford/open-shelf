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

    // ISO 639-2/B (bibliographic) → ISO 639-1 mapping for Locale fallback
    private static let iso639BtoISO639_1: [String: String] = [
        "eng": "en", "spa": "es", "fre": "fr", "ger": "de",
        "por": "pt", "ita": "it", "dut": "nl", "jpn": "ja",
        "chi": "zh", "kor": "ko", "rus": "ru", "ara": "ar",
        "hin": "hi", "swe": "sv", "nor": "no", "dan": "da",
        "fin": "fi", "pol": "pl", "tur": "tr", "cat": "ca",
        "cze": "cs", "gre": "el", "heb": "he", "hun": "hu",
        "ind": "id", "may": "ms", "per": "fa", "rum": "ro",
        "tha": "th", "ukr": "uk", "vie": "vi", "wel": "cy",
        "gle": "ga", "gla": "gd",
        "bul": "bg", "srp": "sr", "hrv": "hr", "slv": "sl",
        "lit": "lt", "lav": "lv", "est": "et", "geo": "ka",
        "arm": "hy", "alb": "sq", "mac": "mk", "ice": "is",
        "baq": "eu", "glg": "gl", "afr": "af", "swa": "sw",
        "ben": "bn", "tam": "ta", "tel": "te", "mar": "mr",
        "urd": "ur", "guj": "gu", "kan": "kn", "mal": "ml",
        "pan": "pa", "sin": "si", "nep": "ne", "bur": "my",
        "khm": "km", "lao": "lo", "tib": "bo", "mon": "mn",
    ]

    static func displayName(for code: String) -> String {
        if let name = codeToName[code] { return name }
        if let iso1 = iso639BtoISO639_1[code],
           let name = Locale.current.localizedString(forLanguageCode: iso1) {
            return name.capitalized
        }
        if let name = Locale.current.localizedString(forLanguageCode: code) {
            return name.capitalized
        }
        return code
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
