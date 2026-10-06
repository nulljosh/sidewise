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
        entries = orderLeftToRight(story.sources)
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
