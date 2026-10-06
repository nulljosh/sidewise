import SwiftUI
import WidgetKit

struct TopStoryEntry: TimelineEntry {
    let date: Date
    let story: Story?
}

struct TopStoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopStoryEntry {
        TopStoryEntry(date: .now, story: Story(title: "Top story loads here", sources: [
            Source(title: "", link: "https://example.com/a", outlet: "NPR", bias: -1),
            Source(title: "", link: "https://example.com/b", outlet: "BBC", bias: 0),
            Source(title: "", link: "https://example.com/c", outlet: "Fox News", bias: 2)], blindspot: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (TopStoryEntry) -> Void) {
        Task { completion(TopStoryEntry(date: .now, story: await Self.topStory())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopStoryEntry>) -> Void) {
        Task {
            let entry = TopStoryEntry(date: .now, story: await Self.topStory())
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
        }
    }

    /// The first story that more than one outlet covers, else the first story.
    static func topStory() async -> Story? {
        guard let (data, _) = try? await URLSession.shared.data(from: URL(string: "https://sidewise.heyitsmejosh.com/api/stories?view=stories&limit=20")!),
              let feed = try? JSONDecoder().decode(Feed.self, from: data) else { return nil }
        let stories = feed.stories.map(\.coherent)
        return comparableStories(stories).first ?? stories.first
    }
}

struct TopStoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TopStoryEntry

    var body: some View {
        if let story = entry.story {
            VStack(alignment: .leading, spacing: 8) {
                Text("TOP STORY").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(story.title)
                    .font(family == .systemSmall ? .footnote.weight(.bold) : .headline.weight(.bold))
                    .lineLimit(family == .systemSmall ? 4 : 3)
                Spacer(minLength: 0)
                BiasBar(story: story, height: 6)
                Text(footer(story)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .widgetURL(URL(string: "https://sidewise.heyitsmejosh.com"))
        } else {
            Text("Open Sidewise to load the news.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func footer(_ story: Story) -> String {
        let c = Comparison(story)
        return c.isComparable ? c.entries.prefix(family == .systemSmall ? 2 : 4).map(\.outletKey).joined(separator: ", ")
            : (c.entries.first.map { "\($0.outletKey) only" } ?? "")
    }
}

struct SidewiseTopStory: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SidewiseTopStory", provider: TopStoryProvider()) { entry in
            TopStoryView(entry: entry).containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Top story")
        .description("The lead story and how left, center and right outlets split on it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SidewiseWidgets: WidgetBundle {
    var body: some Widget { SidewiseTopStory() }
}
