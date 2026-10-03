import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case stories = "Stories"
    case latest = "Latest"
    case saved = "Saved"
    case diet = "My Diet"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .stories: return "square.stack.3d.up"
        case .latest: return "clock"
        case .saved: return "bookmark"
        case .diet: return "chart.bar"
        }
    }
}

struct ContentView: View {
    @StateObject private var service = NewsService()
    @State private var selection: Pane? = .stories
    @State private var filter: StoryFilter = .all
    @State private var query = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Pane.allCases) { s in
                    NavigationLink(value: s) { Label(s.rawValue, systemImage: s.icon) }
                }
            }
            .navigationTitle("Sidewise")
            #if os(macOS)
            .frame(minWidth: 170)
            #endif
        } detail: {
            NavigationStack {
                feedList
                    .navigationTitle(pane.rawValue)
                    .navigationDestination(for: Story.self) { story in
                        StoryDetailView(story: story).environmentObject(service)
                    }
            }
        }
        .searchable(text: $query, prompt: "Search headlines")
        .task { if service.feed == nil { await service.refresh() } }
    }

    private var pane: Pane { selection ?? .stories }

    @ViewBuilder
    private var feedList: some View {
        if pane == .diet {
            DietView().environmentObject(service)
        } else {
            storyList
        }
    }

    private var storyList: some View {
        List {
            if let error = service.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch pane {
            case .stories:
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(StoryFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                ForEach(filterStories(service.feed?.stories ?? [], filter: filter, query: query)) { story in
                    NavigationLink(value: story) { StoryRow(story: story, read: service.isRead(story)) }
                }
            case .latest:
                ForEach(latestSources) { source in
                    Link(destination: source.url ?? URL(string: "https://sidewise.heyitsmejosh.com")!) {
                        SourceRow(source: source)
                    }
                    .simultaneousGesture(TapGesture().onEnded { service.markRead(source) })
                }
            case .diet:
                EmptyView()
            case .saved:
                if service.saved.isEmpty {
                    Text("Nothing saved yet. Open a story and tap the bookmark.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(filterStories(service.saved, filter: .all, query: query)) { story in
                    NavigationLink(value: story) { StoryRow(story: story, read: service.isRead(story)) }
                }
            }
        }
        .refreshable { await service.refresh() }
        .overlay {
            if service.isLoading && service.feed == nil { ProgressView() }
        }
        .toolbar {
            Button {
                Task { await service.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    private var latestSources: [Source] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = service.feed?.latest ?? []
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.lowercased().contains(q) || $0.outlet.lowercased().contains(q) }
    }
}
