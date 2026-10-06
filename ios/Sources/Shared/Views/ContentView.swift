import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case stories = "Stories"
    case compare = "Compare"
    case latest = "Latest"
    case following = "Following"
    case outlets = "Outlets"
    case saved = "Saved"
    case diet = "My Diet"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .stories: return "square.stack.3d.up"
        case .compare: return "rectangle.split.3x1"
        case .latest: return "clock"
        case .following: return "checkmark.circle"
        case .outlets: return "building.columns"
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
    @State private var path = NavigationPath()

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
            NavigationStack(path: $path) {
                feedList
                    .navigationTitle(pane.rawValue)
                    .navigationDestination(for: Story.self) { story in
                        StoryDetailView(story: story).environmentObject(service)
                    }
                    .navigationDestination(for: OutletRoute.self) { route in
                        OutletDetailView(key: route.key).environmentObject(service)
                    }
            }
        }
        .searchable(text: $query, prompt: "Search headlines")
        .task {
            if service.feed == nil { await service.refresh() }
            #if DEBUG
            applyLaunchArguments()
            #endif
        }
    }

    private var pane: Pane { selection ?? .stories }

    @ViewBuilder
    private var feedList: some View {
        if pane == .diet {
            DietView().environmentObject(service)
        } else if pane == .outlets {
            OutletsView().environmentObject(service)
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
                ForEach(filterStories(service.stories, filter: filter, query: query)) { story in
                    NavigationLink(value: story) { StoryRow(story: story, read: service.isRead(story)) }
                }
            case .compare:
                let rows = filterStories(comparableStories(service.stories), filter: .all, query: query)
                if rows.isEmpty {
                    Text("No story has two or more outlets on it right now. Pull to refresh later.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Stories more than one outlet is covering. Open one to read the headlines side by side.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(rows) { story in
                    NavigationLink(value: story) { StoryRow(story: story, read: service.isRead(story)) }
                }
            case .following:
                followingRows
            case .outlets:
                EmptyView()
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

    @ViewBuilder
    private var followingRows: some View {
        if service.prefs.followed.isEmpty {
            Text("Follow an outlet and its stories collect here. Pick one from the Outlets tab, or from any story.")
                .font(.callout).foregroundStyle(.secondary)
        } else {
            let stories = filterStories(followingStories(service.stories, prefs: service.prefs), filter: .all, query: query)
            let recent = followingSources(latestSources, prefs: service.prefs)
            if !stories.isEmpty {
                Section("In stories") {
                    ForEach(stories) { story in
                        NavigationLink(value: story) { StoryRow(story: story, read: service.isRead(story)) }
                    }
                }
            }
            Section("Latest from \(service.prefs.followed.count) followed") {
                ForEach(recent) { source in
                    Link(destination: source.url ?? URL(string: "https://sidewise.heyitsmejosh.com")!) {
                        SourceRow(source: source)
                    }
                    .simultaneousGesture(TapGesture().onEnded { service.markRead(source) })
                }
            }
        }
    }

    private var latestSources: [Source] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = service.latest
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.lowercased().contains(q) || $0.outlet.lowercased().contains(q) }
    }

    #if DEBUG
    /// Debug builds only: `-pane Compare`, `-push compare`, `-push outlet:NPR` and `-seed 1` jump
    /// straight to a screen so it can be photographed. Release builds do not contain this.
    private func applyLaunchArguments() {
        let d = UserDefaults.standard
        if d.string(forKey: "seed") != nil, service.reads.isEmpty, let all = service.feed.map(allSources) {
            for outlet in ["NPR", "BBC", "BBC", "Fox News", "The Guardian", "NBC News", "NPR", "National Post"] {
                if let s = all.first(where: { $0.outletKey == outlet }) { service.markRead(s) }
            }
        }
        for key in (d.string(forKey: "follow") ?? "").split(separator: ",").map(String.init) where !service.prefs.isFollowed(key) {
            service.toggleFollow(key)
        }
        for key in (d.string(forKey: "mute") ?? "").split(separator: ",").map(String.init) where !service.prefs.isMuted(key) {
            service.toggleMute(key)
        }
        if let q = d.string(forKey: "query") { query = q }
        if let name = d.string(forKey: "pane"), let p = Pane(rawValue: name) { selection = p }
        guard let push = d.string(forKey: "push") else { return }
        if push.hasPrefix("compare"), let story = comparableStories(service.stories).first(where: { push == "compare" || $0.title.contains(push.dropFirst(8)) }) { path.append(story) }
        if push == "single", let story = service.stories.first(where: { !Comparison($0).isComparable }) { path.append(story) }
        if push.hasPrefix("outlet:") { path.append(OutletRoute(key: String(push.dropFirst(7)))) }
    }
    #endif
}
