import Foundation

/// How far left or right an outlet sits, on the same -2...+2 scale the API uses.
func biasLabel(_ bias: Int) -> String {
    switch bias {
    case ...(-2): return "Left"
    case -1: return "Leans left"
    case 0: return "Center"
    case 1: return "Leans right"
    default: return "Right"
    }
}

/// One story as each outlet covered it. The API already clusters same-event headlines, so the
/// cluster is the grouping key. This only cleans the cluster up: one entry per outlet, ordered
/// left to right.
struct Comparison: Equatable {
    let entries: [Source]

    init(_ story: Story) {
        entries = orderLeftToRight(story.coherent.sources)
    }

    /// A comparison needs at least two different outlets. One outlet is just a headline.
    var isComparable: Bool { entries.count >= 2 }

    /// Sides that did not cover it, so the screen can say what is missing.
    var missingSides: [Side] {
        let have = Set(entries.map(\.side))
        return Side.allCases.filter { !have.contains($0) }
    }
}

/// One entry per outlet (first headline wins), sorted by bias, then outlet name.
func orderLeftToRight(_ sources: [Source]) -> [Source] {
    var seen = Set<String>()
    let unique = sources.filter { seen.insert($0.outletKey).inserted }
    return unique.sorted { a, b in
        a.bias != b.bias ? a.bias < b.bias : a.outletKey.localizedCaseInsensitiveCompare(b.outletKey) == .orderedAscending
    }
}

/// Stories worth comparing: two or more distinct outlets, widest coverage first.
func comparableStories(_ stories: [Story]) -> [Story] {
    stories.filter { Comparison($0).isComparable }
        .sorted { Comparison($0).entries.count > Comparison($1).entries.count }
}

// MARK: - Cluster guard

private let stopWords: Set<String> = [
    "this", "that", "with", "from", "have", "will", "after", "over", "about", "their", "they", "what",
    "when", "your", "more", "into", "than", "been", "were", "just", "says", "said", "amid", "could",
    "would", "does", "most", "also", "very", "some", "such", "only", "here", "there", "them", "then",
    "these", "those", "while", "where", "which", "being", "other", "first", "news", "live",
]

/// The words that carry a headline: lowercase, apostrophes dropped, at least four letters, no stop words.
func meaningfulWords(_ title: String) -> Set<String> {
    let cleaned = title.lowercased().replacingOccurrences(of: "\u{2019}", with: "").replacingOccurrences(of: "'", with: "")
    let words = cleaned.split { !($0.isLetter || $0.isNumber) }.map(String.init)
    return Set(words.filter { $0.count >= 4 && !stopWords.contains($0) })
}

extension Story {
    /// The story with off-topic headlines removed. The feed's clustering is by loose keyword overlap
    /// and sometimes pulls in an unrelated item (a tech blog post inside a politics story). A headline
    /// stays only if it is the cluster's own title or shares at least two meaningful words with it
    /// (one, when the cluster title has just one). Deterministic and conservative: a true match
    /// with unusual wording can be dropped, an unrelated item is not shown.
    var coherent: Story {
        let lead = meaningfulWords(title)
        let need = max(1, min(2, lead.count))
        let kept = sources.filter { $0.title == title || lead.intersection(meaningfulWords($0.title)).count >= need }
        guard kept.count != sources.count, !kept.isEmpty else { return self }
        return Story(title: title, sources: kept, blindspot: blindspot)
    }
}
