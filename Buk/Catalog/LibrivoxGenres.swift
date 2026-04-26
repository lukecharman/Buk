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
