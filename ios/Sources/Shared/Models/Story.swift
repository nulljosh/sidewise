import Foundation

/// One outlet's headline for a story. `bias` is -2 (left) … +2 (right); 0 is center.
struct Source: Codable, Hashable, Identifiable {
    let title: String
    let link: String
    let outlet: String
    let bias: Int
    /// The newsroom behind the feed, when the API says so (NY Post and NY Post Opinion are one voice).
    var publisher: String? = nil
    /// Publish time in milliseconds since 1970, when the feed gave one.
    var ts: Double? = nil

    var id: String { link }
    /// What identifies the outlet for following, muting and comparing.
    var outletKey: String { publisher ?? outlet }
    var date: Date? { ts.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0 / 1000) : nil } }
    var side: Side { bias < 0 ? .left : bias > 0 ? .right : .center }
    var url: URL? { URL(string: link) }
}

enum Side: String, Codable, CaseIterable {
    case left, center, right
}

/// A cluster of headlines from different outlets about the same event.
struct Story: Codable, Hashable, Identifiable {
    let title: String
    let sources: [Source]
    let blindspot: Bool

    var id: String { title }

    func count(_ side: Side) -> Int { sources.filter { $0.side == side }.count }

    /// The one political side covering this, if only one does.
    var lonelySide: Side? {
        let sides = Set(sources.map(\.side))
        return sides.count == 1 ? sides.first : nil
    }

    var outlets: String {
        sources.map(\.outlet).joined(separator: ", ")
    }
}

struct Feed: Codable {
    let updated: Double
    let stories: [Story]
    let latest: [Source]

    var updatedAt: Date { Date(timeIntervalSince1970: updated / 1000) }
}
