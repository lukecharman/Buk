import Foundation

/// Curated grouping of LibriVox genres, used by the "Browse by Genre" detail view.
///
/// LibriVox doesn't expose an enumeration endpoint for its genre vocabulary —
/// `/api/feed/genres` returns 404. Names here are the literal `genre.name`
/// values returned on book records, since the `genre=` query parameter is an
/// exact match (case-sensitive). New names appearing in the catalog will be
/// missing from this list until added; the API will simply not surface them
/// as a row, which fails gracefully.
///
/// Erotica is intentionally omitted.
enum LibrivoxGenres {
    struct Group: Identifiable, Hashable {
        let title: String
        let genres: [String]
        var id: String { title }
    }

    /// Returns a small emoji for the given LibriVox genre name. Handles the
    /// curated vocabulary below via exact match, and falls back to a keyword
    /// lookup so genres that come back from the API but aren't in our list
    /// (e.g. on a book's `genres` field) still get something appropriate.
    static func emoji(for genre: String) -> String {
        if let exact = exactEmoji[genre] { return exact }

        let lower = genre.lowercased()
        for (keyword, symbol) in keywordEmoji where lower.contains(keyword) {
            return symbol
        }
        return "📚"
    }

    private static let exactEmoji: [String: String] = [
        // Fiction
        "General Fiction": "📖",
        "Literary Fiction": "✒️",
        "Short Stories": "📃",
        "Anthologies": "📚",
        "Single Author Collections": "📑",
        "Action & Adventure Fiction": "⚔️",
        "Action & Adventure": "⚔️",
        "Romance": "❤️",
        "Historical Fiction": "🏰",
        "Detective Fiction": "🕵️",
        "Crime & Mystery Fiction": "🔎",
        "Horror & Supernatural Fiction": "👻",
        "Fantastic Fiction": "🧙",
        "Science Fiction": "🚀",
        "Humorous Fiction": "🤣",
        "Humor": "🤣",
        "Satire": "🃏",
        "Westerns": "🤠",
        "Nautical & Marine Fiction": "⚓",
        "Family Life": "🏡",
        "Epistolary Fiction": "✉️",
        "Christian Fiction": "✝️",
        "Nature & Animal Fiction": "🦊",
        "Fictional Biographies & Memoirs": "👤",
        "War & Military Fiction": "🎖️",
        // Drama & Poetry
        "Plays": "🎭",
        "Drama": "🎬",
        "Tragedy": "😢",
        "Comedy": "😂",
        "Poetry": "🪶",
        "Sonnets": "💝",
        "Epics": "🛡️",
        "Multi-version (Weekly and Fortnightly poetry)": "📜",
        // Children's
        "Children's Fiction": "🧸",
        "Children's Non-fiction": "🎒",
        "Myths, Legends & Fairy Tales": "🧚",
        "School": "🏫",
        // Non-fiction
        "*Non-fiction": "📰",
        "Essays & Short Works": "📝",
        "Short works": "📝",
        "Biography & Autobiography": "👤",
        "Memoirs": "📔",
        "History": "🏛️",
        "Travel & Geography": "🌍",
        "Exploration": "🧭",
        "Animals & Nature": "🦊",
        "Nature": "🌿",
        "House & Home": "🏠",
        "Cooking": "🍳",
        "War & Military": "🎖️",
        "Psychology": "🧠",
        "Medical": "⚕️",
        "Philosophy": "💭",
        "Religion": "🕊️",
        "Christianity - Other": "✝️",
        "Judaism": "✡️",
        // Science & Maths
        "Astronomy, Physics & Mechanics": "🔭",
        "Mathematics": "➗",
        // Bibles
        "Bibles": "📖",
        "King James Version": "👑",
        "World English Bible": "🌐",
        "American Standard Version": "🇺🇸",
        "Douay-Rheims Version": "⛪",
        // Eras
        "Classics (Greek & Latin Antiquity)": "🏛️",
        "Ancient": "🏺",
        "Medieval": "🛡️",
        "Middle Ages/Middle History": "🏰",
        "Early Modern": "🎩",
        "Modern (19th C)": "🎩",
        "Modern": "🌆",
        "Contemporary": "🌆",
        "Published 1800 -1900": "🕰️",
        "Published 1900 onward": "📻"
    ]

    /// Ordered keyword fallbacks — first match wins, so put more specific
    /// keywords (e.g. "fairy") above more general ones (e.g. "fiction").
    private static let keywordEmoji: [(String, String)] = [
        ("fairy", "🧚"),
        ("myth", "🧚"),
        ("legend", "🧚"),
        ("children", "🧸"),
        ("school", "🏫"),
        ("poetry", "🪶"),
        ("sonnet", "💝"),
        ("epic", "🛡️"),
        ("play", "🎭"),
        ("tragedy", "😢"),
        ("comedy", "😂"),
        ("drama", "🎬"),
        ("humor", "🤣"),
        ("humour", "🤣"),
        ("satire", "🃏"),
        ("western", "🤠"),
        ("romance", "❤️"),
        ("erotic", "🌶️"),
        ("detective", "🕵️"),
        ("mystery", "🔎"),
        ("crime", "🔎"),
        ("horror", "👻"),
        ("supernatural", "👻"),
        ("ghost", "👻"),
        ("vampire", "🦇"),
        ("fantastic", "🧙"),
        ("fantasy", "🧙"),
        ("science fiction", "🚀"),
        ("sci-fi", "🚀"),
        ("space", "🌌"),
        ("astronom", "🔭"),
        ("physics", "🔭"),
        ("mechanics", "⚙️"),
        ("math", "➗"),
        ("medic", "⚕️"),
        ("psycholog", "🧠"),
        ("philosoph", "💭"),
        ("religion", "🕊️"),
        ("christ", "✝️"),
        ("bible", "📖"),
        ("judaism", "✡️"),
        ("islam", "☪️"),
        ("buddh", "☸️"),
        ("hindu", "🕉️"),
        ("travel", "🌍"),
        ("geograph", "🌍"),
        ("exploration", "🧭"),
        ("nautical", "⚓"),
        ("marine", "⚓"),
        ("nature", "🌿"),
        ("animal", "🦊"),
        ("garden", "🌷"),
        ("cook", "🍳"),
        ("food", "🍽️"),
        ("home", "🏠"),
        ("family", "🏡"),
        ("war", "🎖️"),
        ("military", "🎖️"),
        ("history", "🏛️"),
        ("ancient", "🏺"),
        ("medieval", "🛡️"),
        ("middle ages", "🏰"),
        ("modern", "🎩"),
        ("contemporary", "🌆"),
        ("biograph", "👤"),
        ("memoir", "📔"),
        ("autobiograph", "👤"),
        ("essay", "📝"),
        ("letter", "✉️"),
        ("epistolary", "✉️"),
        ("anthology", "📚"),
        ("collection", "📑"),
        ("short", "📃"),
        ("plays", "🎭"),
        ("classic", "🏛️"),
        ("non-fiction", "📰"),
        ("nonfiction", "📰"),
        ("fiction", "📖")
    ]

    static let groups: [Group] = [
        Group(title: "Fiction", genres: [
            "General Fiction",
            "Literary Fiction",
            "Short Stories",
            "Anthologies",
            "Single Author Collections",
            "Action & Adventure Fiction",
            "Romance",
            "Historical Fiction",
            "Detective Fiction",
            "Crime & Mystery Fiction",
            "Horror & Supernatural Fiction",
            "Fantastic Fiction",
            "Science Fiction",
            "Humorous Fiction",
            "Satire",
            "Westerns",
            "Nautical & Marine Fiction",
            "Family Life",
            "Epistolary Fiction",
            "Christian Fiction",
            "Nature & Animal Fiction",
            "Fictional Biographies & Memoirs",
            "War & Military Fiction"
        ]),
        Group(title: "Drama & Poetry", genres: [
            "Plays",
            "Tragedy",
            "Comedy",
            "Drama",
            "Poetry",
            "Sonnets",
            "Epics",
            "Multi-version (Weekly and Fortnightly poetry)"
        ]),
        Group(title: "Children's", genres: [
            "Children's Fiction",
            "Children's Non-fiction",
            "Myths, Legends & Fairy Tales",
            "School"
        ]),
        Group(title: "Non-fiction", genres: [
            "*Non-fiction",
            "Essays & Short Works",
            "Biography & Autobiography",
            "Memoirs",
            "History",
            "Travel & Geography",
            "Exploration",
            "Animals & Nature",
            "Nature",
            "House & Home",
            "Cooking",
            "War & Military",
            "Psychology",
            "Medical",
            "Philosophy",
            "Religion",
            "Christianity - Other"
        ]),
        Group(title: "Science & Maths", genres: [
            "Astronomy, Physics & Mechanics",
            "Mathematics"
        ]),
        Group(title: "Bibles", genres: [
            "Bibles",
            "King James Version",
            "World English Bible",
            "American Standard Version",
            "Douay-Rheims Version"
        ]),
        Group(title: "By Era", genres: [
            "Classics (Greek & Latin Antiquity)",
            "Ancient",
            "Medieval",
            "Middle Ages/Middle History",
            "Early Modern",
            "Modern (19th C)",
            "Modern",
            "Contemporary",
            "Published 1800 -1900",
            "Published 1900 onward"
        ])
    ]
}
