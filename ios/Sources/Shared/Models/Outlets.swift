import Foundation

/// Follow and mute choices. Followed outlets get their own filter; muted ones are hidden.
struct OutletPrefs: Codable, Equatable {
    var followed: [String] = []
    var muted: [String] = []

    func isFollowed(_ key: String) -> Bool { followed.contains(key) }
    func isMuted(_ key: String) -> Bool { muted.contains(key) }

    mutating func toggleFollow(_ key: String) {
        if let i = followed.firstIndex(of: key) { followed.remove(at: i) } else {
            followed.append(key)
            muted.removeAll { $0 == key }
        }
    }

    mutating func toggleMute(_ key: String) {
        if let i = muted.firstIndex(of: key) { muted.remove(at: i) } else {
            muted.append(key)
            followed.removeAll { $0 == key }
        }
    }
}

/// An outlet as the feed describes it.
struct OutletInfo: Identifiable, Equatable {
    let key: String
    let bias: Int
    let count: Int
    var id: String { key }
    var side: Side { bias < 0 ? .left : bias > 0 ? .right : .center }
}

/// Every outlet seen in the feed, left to right.
func outletDirectory(_ feed: Feed) -> [OutletInfo] {
    var bias: [String: Int] = [:], count: [String: Int] = [:]
    for s in allSources(feed) {
        bias[s.outletKey] = bias[s.outletKey] ?? s.bias
        count[s.outletKey, default: 0] += 1
    }
    return bias.map { OutletInfo(key: $0.key, bias: $0.value, count: count[$0.key] ?? 0) }
        .sorted { $0.bias != $1.bias ? $0.bias < $1.bias : $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
}

/// Every distinct headline in the feed, from the clustered stories and the flat latest list.
func allSources(_ feed: Feed) -> [Source] {
    var seen = Set<String>()
    return (feed.latest + feed.stories.flatMap(\.sources)).filter { seen.insert($0.link).inserted }
}

/// The outlet's headlines, newest first.
func recentSources(of key: String, in feed: Feed) -> [Source] {
    allSources(feed).filter { $0.outletKey == key }.sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
}

/// Muted outlets disappear from clusters. A cluster left empty is dropped.
func hideMuted(_ stories: [Story], prefs: OutletPrefs) -> [Story] {
    guard !prefs.muted.isEmpty else { return stories }
    return stories.compactMap { story in
        let kept = story.sources.filter { !prefs.isMuted($0.outletKey) }
        guard !kept.isEmpty else { return nil }
        return kept.count == story.sources.count ? story
            : Story(title: story.title, sources: kept, blindspot: story.blindspot)
    }
}

func hideMuted(_ sources: [Source], prefs: OutletPrefs) -> [Source] {
    sources.filter { !prefs.isMuted($0.outletKey) }
}

/// Stories at least one followed outlet covered.
func followingStories(_ stories: [Story], prefs: OutletPrefs) -> [Story] {
    stories.filter { s in s.sources.contains { prefs.isFollowed($0.outletKey) } }
}

func followingSources(_ sources: [Source], prefs: OutletPrefs) -> [Source] {
    sources.filter { prefs.isFollowed($0.outletKey) }
}
