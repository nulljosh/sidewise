import XCTest
@testable import Sidewise_iOS

final class CompareTests: XCTestCase {
    private func src(_ outlet: String, _ bias: Int, _ title: String = "h", link: String? = nil, publisher: String? = nil, ts: Double? = nil) -> Source {
        Source(title: title, link: link ?? "https://example.com/\(outlet)/\(title)", outlet: outlet, bias: bias, publisher: publisher, ts: ts)
    }

    func testOrderLeftToRightThenName() {
        let out = orderLeftToRight([src("Fox", 2), src("NPR", -1), src("BBC", 0), src("CBC", -1), src("Post", 2, "x")])
        XCTAssertEqual(out.map(\.outlet), ["CBC", "NPR", "BBC", "Fox", "Post"])
    }

    func testDuplicateOutletKeepsFirstHeadline() {
        let out = orderLeftToRight([src("NBC", -1, "first"), src("NBC", -1, "second")])
        XCTAssertEqual(out.map(\.title), ["first"])
    }

    func testPublisherCollapsesTwoFeedsIntoOneVoice() {
        let a = src("NY Post", 2, "a", publisher: "NY Post"), b = src("New York Post Opinion", 2, "b", publisher: "NY Post")
        let c = Comparison(Story(title: "T", sources: [a, b], blindspot: true))
        XCTAssertEqual(c.entries.count, 1)
        XCTAssertFalse(c.isComparable)
    }

    func testSingleOutletIsNotAComparison() {
        XCTAssertFalse(Comparison(Story(title: "T", sources: [src("BBC", 0)], blindspot: false)).isComparable)
        XCTAssertFalse(Comparison(Story(title: "T", sources: [], blindspot: false)).isComparable)
    }

    func testMissingSides() {
        let c = Comparison(Story(title: "T", sources: [src("NPR", -1), src("BBC", 0)], blindspot: false))
        XCTAssertTrue(c.isComparable)
        XCTAssertEqual(c.missingSides, [.right])
    }

    func testComparableStoriesWidestFirst() {
        let two = Story(title: "two", sources: [src("NPR", -1), src("Fox", 2)], blindspot: false)
        let three = Story(title: "three", sources: [src("NPR", -1), src("BBC", 0), src("Fox", 2)], blindspot: false)
        let one = Story(title: "one", sources: [src("NPR", -1)], blindspot: false)
        XCTAssertEqual(comparableStories([one, two, three]).map(\.title), ["three", "two"])
    }

    func testBiasLabels() {
        XCTAssertEqual([-2, -1, 0, 1, 2].map(biasLabel), ["Left", "Leans left", "Center", "Leans right", "Right"])
    }

    func testDecodesRealFieldsAndOldPayloads() throws {
        let json = #"{"title":"T","link":"https://a","outlet":"New York Post Opinion","publisher":"NY Post","bias":2,"ts":1791254802000,"summary":"x"}"#
        let s = try JSONDecoder().decode(Source.self, from: Data(json.utf8))
        XCTAssertEqual(s.outletKey, "NY Post")
        XCTAssertNotNil(s.date)
        let old = try JSONDecoder().decode(Source.self, from: Data(#"{"title":"T","link":"https://a","outlet":"BBC","bias":0}"#.utf8))
        XCTAssertEqual(old.outletKey, "BBC")
        XCTAssertNil(old.date)
    }
}

final class OutletTests: XCTestCase {
    private func src(_ outlet: String, _ bias: Int, _ n: Int, ts: Double? = nil) -> Source {
        Source(title: "\(outlet) \(n)", link: "https://x.com/\(outlet)/\(n)", outlet: outlet, bias: bias, ts: ts)
    }
    private lazy var feed = Feed(
        updated: 0,
        stories: [Story(title: "S", sources: [src("NPR", -1, 1), src("Fox", 2, 1)], blindspot: false),
                  Story(title: "Fox only", sources: [src("Fox", 2, 2)], blindspot: true)],
        latest: [src("NPR", -1, 1, ts: 5), src("NPR", -1, 3, ts: 9), src("BBC", 0, 1)]
    )

    func testFollowAndMuteExcludeEachOther() {
        var p = OutletPrefs()
        p.toggleFollow("NPR")
        XCTAssertTrue(p.isFollowed("NPR"))
        p.toggleMute("NPR")
        XCTAssertTrue(p.isMuted("NPR")); XCTAssertFalse(p.isFollowed("NPR"))
        p.toggleFollow("NPR")
        XCTAssertTrue(p.isFollowed("NPR")); XCTAssertFalse(p.isMuted("NPR"))
        p.toggleFollow("NPR")
        XCTAssertFalse(p.isFollowed("NPR"))
    }

    func testHideMutedDropsOutletAndEmptyStories() {
        var p = OutletPrefs(); p.toggleMute("Fox")
        let out = hideMuted(feed.stories, prefs: p)
        XCTAssertEqual(out.map(\.title), ["S"])
        XCTAssertEqual(out[0].sources.map(\.outlet), ["NPR"])
        XCTAssertEqual(hideMuted(feed.latest, prefs: p).count, 3)
    }

    func testFollowingFilter() {
        var p = OutletPrefs(); p.toggleFollow("Fox")
        XCTAssertEqual(followingStories(feed.stories, prefs: p).map(\.title), ["S", "Fox only"])
        XCTAssertEqual(followingSources(feed.latest, prefs: p).count, 0)
    }

    func testDirectoryIsLeftToRightAndDeduped() {
        let d = outletDirectory(feed)
        XCTAssertEqual(d.map(\.key), ["NPR", "BBC", "Fox"])
        XCTAssertEqual(d.first { $0.key == "NPR" }?.count, 2, "same link in stories and latest counts once")
    }

    func testRecentIsNewestFirst() {
        XCTAssertEqual(recentSources(of: "NPR", in: feed).map(\.title), ["NPR 3", "NPR 1"])
    }

    @MainActor func testPrefsPersist() {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let a = NewsService(caches: base, support: base)
        a.toggleFollow("BBC"); a.toggleMute("Fox")
        let b = NewsService(caches: base, support: base)
        XCTAssertTrue(b.prefs.isFollowed("BBC")); XCTAssertTrue(b.prefs.isMuted("Fox"))
    }
}

final class WeeklyDietTests: XCTestCase {
    private let now = Date()
    private func read(_ outlet: String, _ bias: Int?, daysAgo: Double, side: Side) -> ReadEvent {
        ReadEvent(link: UUID().uuidString, side: side, date: now.addingTimeInterval(-daysAgo * 86_400), outlet: outlet, bias: bias)
    }

    func testWeekWindow() {
        let reads = [read("NPR", -1, daysAgo: 1, side: .left), read("Fox", 2, daysAgo: 6.9, side: .right), read("BBC", 0, daysAgo: 8, side: .center)]
        let d = diet(reads, now: now)
        XCTAssertEqual(d.total, 2); XCTAssertEqual(d.center, 0)
        XCTAssertEqual(diet(reads, days: 30, now: now).total, 3)
    }

    func testAverageLean() {
        XCTAssertEqual(averageLean([read("a", -2, daysAgo: 0, side: .left), read("b", 2, daysAgo: 0, side: .right), read("c", 2, daysAgo: 0, side: .right)])!, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertNil(averageLean([read("old", nil, daysAgo: 0, side: .left)]))
        XCTAssertNil(averageLean([]))
    }

    func testTopOutletsTieBreak() {
        let reads = [read("NPR", -1, daysAgo: 0, side: .left), read("Fox", 2, daysAgo: 0, side: .right), read("Fox", 2, daysAgo: 0, side: .right), read("BBC", 0, daysAgo: 0, side: .center)]
        let top = topOutlets(reads, limit: 2)
        XCTAssertEqual(top.map(\.outlet), ["Fox", "BBC"])
        XCTAssertEqual(top.map(\.count), [2, 1])
    }

    func testOldReadsWithoutOutletStillDecode() throws {
        let json = #"[{"link":"a","side":"left","date":0}]"#
        let reads = try JSONDecoder().decode([ReadEvent].self, from: Data(json.utf8))
        XCTAssertNil(reads[0].outlet)
    }
}
