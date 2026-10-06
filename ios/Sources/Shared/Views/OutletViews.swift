import SwiftUI

/// Navigation value for an outlet screen.
struct OutletRoute: Hashable {
    let key: String
}

/// One outlet's headline on a story: who, where it sits, what it said, and a link out.
struct OutletCard: View {
    let source: Source
    @EnvironmentObject var service: NewsService
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                NavigationLink(value: OutletRoute(key: source.outletKey)) {
                    Text(source.outletKey).font(.subheadline.weight(.bold))
                }
                .buttonStyle(.plain)
                Spacer()
                if service.prefs.isFollowed(source.outletKey) {
                    Text("Following").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            BiasScale(bias: source.bias)
            Text(source.title).font(.body).fixedSize(horizontal: false, vertical: true)
            Button {
                service.markRead(source)
                if let url = source.url { openURL(url) }
            } label: {
                Label("Read at \(source.outletKey)", systemImage: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }
}

/// Every outlet in the feed, left to right, with its rating and follow state.
struct OutletsView: View {
    @EnvironmentObject var service: NewsService

    var body: some View {
        List {
            if let feed = service.feed {
                ForEach(outletDirectory(feed)) { outlet in
                    NavigationLink(value: OutletRoute(key: outlet.key)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(outlet.key).font(.headline)
                                BiasScale(bias: outlet.bias)
                            }
                            Spacer()
                            if service.prefs.isFollowed(outlet.key) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.primary)
                                    .accessibilityLabel("Following")
                            } else if service.prefs.isMuted(outlet.key) {
                                Image(systemName: "speaker.slash.fill").foregroundStyle(.secondary)
                                    .accessibilityLabel("Muted")
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(service.prefs.isMuted(outlet.key) ? "Unmute" : "Mute") { service.toggleMute(outlet.key) }.tint(.gray)
                        Button(service.prefs.isFollowed(outlet.key) ? "Unfollow" : "Follow") { service.toggleFollow(outlet.key) }.tint(.black)
                    }
                }
            }
        }
        .navigationTitle("Outlets")
    }
}

/// One outlet: its rating, follow and mute, and what it ran recently.
struct OutletDetailView: View {
    let key: String
    @EnvironmentObject var service: NewsService
    @Environment(\.openURL) private var openURL

    var body: some View {
        let recent = service.feed.map { recentSources(of: key, in: $0) } ?? []
        let followed = service.prefs.isFollowed(key), muted = service.prefs.isMuted(key)
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let bias = recent.first?.bias {
                        BiasScale(bias: bias)
                        Text("Sidewise rates \(key) as \(biasLabel(bias).lowercased()). The rating covers the whole outlet, not one story.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text("No recent headlines from \(key) in the feed.").font(.callout).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Button { service.toggleFollow(key) } label: {
                            Text(followed ? "Following" : "Follow").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.primary)
                        Button { service.toggleMute(key) } label: {
                            Text(muted ? "Unmute" : "Mute").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.primary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Recent stories") {
                ForEach(recent) { source in
                    Button {
                        service.markRead(source)
                        if let url = source.url { openURL(url) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.title).font(.subheadline).multilineTextAlignment(.leading)
                            if let date = source.date {
                                Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(key)
    }
}
