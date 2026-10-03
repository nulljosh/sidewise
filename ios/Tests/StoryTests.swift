import XCTest
@testable import Sidewise_iOS

final class StoryTests: XCTestCase {
    private func source(_ outlet: String, _ bias: Int) -> Source {
        Source(title: "\(outlet) headline", link: "https://example.com/\(outlet)", outlet: outlet, bias: bias)
    }

    private lazy var mixed = Story(
        title: "Assad sentenced in absentia",
        sources: [source("NPR", -1), source("BBC", 0), source("Fox News", 2)],
        blindspot: false
    )
    private lazy var rightOnly = Story(
        title: "Border bill stalls",
        sources: [source("Fox News", 2), source("Daily Wire", 2)],
        blindspot: true
    )

    func testSideMapping() {
        XCTAssertEqual(source("NPR", -2).side, .left)
        XCTAssertEqual(source("BBC", 0).side, .center)
        XCTAssertEqual(source("Fox News", 1).side, .right)
    }

    func testCounts() {
        XCTAssertEqual(mixed.count(.left), 1)
        XCTAssertEqual(mixed.count(.center), 1)
        XCTAssertEqual(mixed.count(.right), 1)
        XCTAssertNil(mixed.lonelySide)
        XCTAssertEqual(rightOnly.lonelySide, .right)
    }

    func testFilterBySide() {
        let all = [mixed, rightOnly]
        XCTAssertEqual(filterStories(all, filter: .left, query: "").count, 1)
        XCTAssertEqual(filterStories(all, filter: .right, query: "").count, 2)
        XCTAssertEqual(filterStories(all, filter: .blindspots, query: "").map(\.id), [rightOnly.id])
    }

    func testSearchMatchesTitleSourceAndOutlet() {
        let all = [mixed, rightOnly]
        XCTAssertEqual(filterStories(all, filter: .all, query: "assad").map(\.id), [mixed.id])
        XCTAssertEqual(filterStories(all, filter: .all, query: "daily wire").map(\.id), [rightOnly.id])
        XCTAssertEqual(filterStories(all, filter: .all, query: "  NPR ").map(\.id), [mixed.id])
        XCTAssertTrue(filterStories(all, filter: .all, query: "zzz").isEmpty)
    }

    func testDecodesAPIPayload() throws {
        let json = """
        {"updated":1786462923027,
         "stories":[{"title":"T","sources":[{"title":"T","link":"https://a","outlet":"BBC","bias":0}],"blindspot":false}],
         "latest":[{"title":"T","link":"https://a","outlet":"BBC","bias":0,"ts":1786462923027}]}
        """.data(using: .utf8)!
        let feed = try JSONDecoder().decode(Feed.self, from: json)
        XCTAssertEqual(feed.stories.count, 1)
        XCTAssertEqual(feed.latest.first?.outlet, "BBC")
    }
}

@MainActor
final class DietTests: XCTestCase {
    private func dirs() -> (URL, URL) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let c = base.appendingPathComponent("caches"), s = base.appendingPathComponent("support")
        try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: s, withIntermediateDirectories: true)
        return (c, s)
    }
    private func src(_ n: String, _ bias: Int) -> Source {
        Source(title: n, link: "https://example.com/\(n)", outlet: n, bias: bias)
    }

    func testDietCountsOnlyTheLast30Days() {
        let now = Date()
        let reads = [
            ReadEvent(link: "a", side: .left, date: now),
            ReadEvent(link: "b", side: .left, date: now.addingTimeInterval(-86_400 * 40)),
            ReadEvent(link: "c", side: .right, date: now),
        ]
        let d = diet(reads, now: now)
        XCTAssertEqual(d.left, 1)
        XCTAssertEqual(d.right, 1)
        XCTAssertEqual(d.total, 2)
    }

    func testBlindSideNeedsEnoughReadsAndALopsidedMix() {
        XCTAssertNil(Diet(left: 3, center: 0, right: 0).blindSide, "too few to say")
        XCTAssertEqual(Diet(left: 9, center: 5, right: 0).blindSide, .right)
        XCTAssertNil(Diet(left: 4, center: 4, right: 4).blindSide, "balanced")
    }

    func testReadsPersistAndMarkAStoryRead() {
        let (c, s) = dirs()
        let service = NewsService(caches: c, support: s)
        let story = Story(title: "T", sources: [src("NPR", -1), src("Fox", 2)], blindspot: false)
        XCTAssertFalse(service.isRead(story))
        service.markRead(story.sources[0])
        XCTAssertTrue(service.isRead(story))
        XCTAssertEqual(NewsService(caches: c, support: s).reads.count, 1, "survives relaunch")
        service.clearReads()
        XCTAssertTrue(NewsService(caches: c, support: s).reads.isEmpty)
    }

    func testSavedMovesOutOfCaches() throws {
        let (c, s) = dirs()
        let story = Story(title: "Old save", sources: [src("BBC", 0)], blindspot: false)
        try JSONEncoder().encode([story]).write(to: c.appendingPathComponent("sidewise-saved.json"))
        let service = NewsService(caches: c, support: s)
        XCTAssertEqual(service.saved.map(\.title), ["Old save"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: c.appendingPathComponent("sidewise-saved.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: s.appendingPathComponent("sidewise-saved.json").path))
    }
}
