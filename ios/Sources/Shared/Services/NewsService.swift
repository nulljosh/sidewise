import Foundation

@MainActor
final class NewsService: ObservableObject {
    @Published var feed: Feed?
    @Published var isLoading = false
    @Published var error: String?
    /// Stories the user saved. Persisted so saves survive a relaunch.
    @Published private(set) var saved: [Story] = []
    /// Every outlet link the user opened, newest first. Feeds the reading diet. Stays on the device.
    @Published private(set) var reads: [ReadEvent] = []

    /// Followed and muted outlets. Stays on the device.
    @Published private(set) var prefs = OutletPrefs()

    private let endpoint = URL(string: "https://sidewise.heyitsmejosh.com/api/stories")!
    private let cacheURL: URL
    private let savedURL: URL
    private let readsURL: URL
    private let prefsURL: URL

    init(caches: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0],
         support: URL = NewsService.defaultSupport) {
        cacheURL = caches.appendingPathComponent("sidewise-feed.json")
        savedURL = support.appendingPathComponent("sidewise-saved.json")
        readsURL = support.appendingPathComponent("sidewise-reads.json")
        prefsURL = support.appendingPathComponent("sidewise-outlets.json")
        // Saves used to live in Caches, which the system may empty. Move them somewhere safe.
        let old = caches.appendingPathComponent("sidewise-saved.json")
        if !FileManager.default.fileExists(atPath: savedURL.path), FileManager.default.fileExists(atPath: old.path) {
            try? FileManager.default.moveItem(at: old, to: savedURL)
        }
        feed = try? JSONDecoder().decode(Feed.self, from: Data(contentsOf: cacheURL))
        saved = (try? JSONDecoder().decode([Story].self, from: Data(contentsOf: savedURL))) ?? []
        reads = (try? JSONDecoder().decode([ReadEvent].self, from: Data(contentsOf: readsURL))) ?? []
        prefs = (try? JSONDecoder().decode(OutletPrefs.self, from: Data(contentsOf: prefsURL))) ?? OutletPrefs()
    }

    nonisolated static var defaultSupport: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: endpoint)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            feed = try JSONDecoder().decode(Feed.self, from: data)
            error = nil
            try? data.write(to: cacheURL, options: .atomic)
        } catch {
            // Keep whatever the cache gave us; only the banner changes.
            self.error = (error as? URLError)?.localizedDescription ?? error.localizedDescription
        }
    }

    // MARK: - Reading diet

    func markRead(_ source: Source, now: Date = .now) {
        reads.insert(ReadEvent(link: source.link, side: source.side, date: now, outlet: source.outletKey, bias: source.bias), at: 0)
        if reads.count > 2000 { reads.removeLast(reads.count - 2000) }
        try? JSONEncoder().encode(reads).write(to: readsURL, options: .atomic)
    }

    func clearReads() {
        reads = []
        try? JSONEncoder().encode(reads).write(to: readsURL, options: .atomic)
    }

    /// A story counts as read once any of its outlets was opened.
    func isRead(_ story: Story) -> Bool {
        let links = Set(reads.map(\.link))
        return story.sources.contains { links.contains($0.link) }
    }

    // MARK: - Outlets

    func toggleFollow(_ key: String) { prefs.toggleFollow(key); savePrefs() }
    func toggleMute(_ key: String) { prefs.toggleMute(key); savePrefs() }

    private func savePrefs() {
        try? JSONEncoder().encode(prefs).write(to: prefsURL, options: .atomic)
    }

    /// Stories with muted outlets taken out.
    var stories: [Story] { hideMuted((feed?.stories ?? []).map(\.coherent), prefs: prefs) }
    var latest: [Source] { hideMuted(feed?.latest ?? [], prefs: prefs) }

    // MARK: - Saved

    func isSaved(_ story: Story) -> Bool { saved.contains { $0.id == story.id } }

    func toggleSave(_ story: Story) {
        if let i = saved.firstIndex(where: { $0.id == story.id }) {
            saved.remove(at: i)
        } else {
            saved.insert(story, at: 0)
        }
        try? JSONEncoder().encode(saved).write(to: savedURL, options: .atomic)
    }
}

/// Filtering lives outside the service so it stays pure and testable.
enum StoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case blindspots = "Blindspots"
    case left = "Left"
    case center = "Center"
    case right = "Right"

    var id: String { rawValue }

    func matches(_ story: Story) -> Bool {
        switch self {
        case .all: return true
        case .blindspots: return story.blindspot
        case .left: return story.count(.left) > 0
        case .center: return story.count(.center) > 0
        case .right: return story.count(.right) > 0
        }
    }
}

func filterStories(_ stories: [Story], filter: StoryFilter, query: String) -> [Story] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    return stories.filter { story in
        guard filter.matches(story) else { return false }
        guard !q.isEmpty else { return true }
        return story.title.lowercased().contains(q)
            || story.sources.contains { $0.title.lowercased().contains(q) || $0.outlet.lowercased().contains(q) }
    }
}

struct ReadEvent: Codable, Equatable {
    let link: String
    let side: Side
    let date: Date
    /// Older saved reads have neither of these.
    var outlet: String? = nil
    var bias: Int? = nil
}

struct Diet: Equatable {
    var left = 0, center = 0, right = 0
    var total: Int { left + center + right }

    func share(_ side: Side) -> Double {
        guard total > 0 else { return 0 }
        let n = side == .left ? left : side == .center ? center : right
        return Double(n) / Double(total)
    }

    /// The side you open least, once there is enough to say anything.
    var blindSide: Side? {
        guard total >= 5 else { return nil }
        let counts: [(Side, Int)] = [(.left, left), (.center, center), (.right, right)]
        return counts.min { $0.1 < $1.1 }.flatMap { $0.1 * 5 < total ? $0.0 : nil }
    }
}

/// Opens in the last `days` days (a week by default), counted by the side of the outlet.
func diet(_ reads: [ReadEvent], days: Int = 7, now: Date = .now) -> Diet {
    var d = Diet()
    for r in readsWithin(days, of: reads, now: now) {
        switch r.side {
        case .left: d.left += 1
        case .center: d.center += 1
        case .right: d.right += 1
        }
    }
    return d
}

func readsWithin(_ days: Int, of reads: [ReadEvent], now: Date = .now) -> [ReadEvent] {
    let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
    return reads.filter { $0.date >= cutoff && $0.date <= now.addingTimeInterval(60) }
}

/// Average lean of what was opened, -2 (left) to +2 (right). Nil when no read carries a rating.
func averageLean(_ reads: [ReadEvent]) -> Double? {
    let rated = reads.compactMap(\.bias)
    guard !rated.isEmpty else { return nil }
    return Double(rated.reduce(0, +)) / Double(rated.count)
}

/// Most-opened outlets, ties broken by name.
func topOutlets(_ reads: [ReadEvent], limit: Int = 3) -> [(outlet: String, count: Int)] {
    var counts: [String: Int] = [:]
    for r in reads { if let o = r.outlet { counts[o, default: 0] += 1 } }
    return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        .prefix(limit).map { (outlet: $0.key, count: $0.value) }
}
