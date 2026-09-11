import SwiftUI

struct ContentView: View {
    @StateObject private var fetcher = StoriesFetcher()

    var body: some View {
        NavigationStack {
            List {
                if fetcher.loading {
                    ProgressView()
                } else if fetcher.failed {
                    VStack(spacing: 6) {
                        Text("Couldn't load")
                        Button("Retry") { Task { await fetcher.load() } }
                    }
                } else {
                    ForEach(fetcher.stories) { story in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.title)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(3)
                            if let outlet = story.sources.first?.outlet {
                                Text(outlet)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Sidewise")
        }
        .task { await fetcher.load() }
    }
}
