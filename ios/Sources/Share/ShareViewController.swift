import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share a link from Safari (or any app) to Sidewise and see how the outlet is rated.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel()
        let host = UIHostingController(rootView: ShareResultView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await model.load(from: extensionContext?.inputItems as? [NSExtensionItem] ?? []) }
    }
}

@MainActor
final class ShareModel: ObservableObject {
    enum State { case loading, rated(Source, URL), unrated(URL), noLink, offline(URL) }
    @Published var state = State.loading

    func load(from items: [NSExtensionItem]) async {
        guard let url = await Self.link(in: items) else { state = .noLink; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "https://sidewise.heyitsmejosh.com/api/stories")!)
            let feed = try JSONDecoder().decode(Feed.self, from: data)
            let index = DomainIndex(allSources(feed))
            if let outlet = index.outlet(for: url) { state = .rated(outlet, url) } else { state = .unrated(url) }
        } catch {
            state = .offline(url)
        }
    }

    private static func link(in items: [NSExtensionItem]) async -> URL? {
        for provider in items.flatMap({ $0.attachments ?? [] }) where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                if let url = item as? URL { return url }
                if let text = item as? String, let url = URL(string: text) { return url }
            }
        }
        return nil
    }
}

struct ShareResultView: View {
    @ObservedObject var model: ShareModel
    var done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sidewise").font(.headline)
                Spacer()
                Button("Done", action: done).fontWeight(.semibold)
            }
            switch model.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            case .rated(let outlet, let url):
                Text(outlet.outletKey).font(.title.weight(.bold))
                BiasScale(bias: outlet.bias)
                Text("Sidewise rates \(outlet.outletKey) as \(biasLabel(outlet.bias).lowercased()). The rating covers the whole outlet, not this article.")
                    .font(.callout).foregroundStyle(.secondary)
                Text(url.host ?? "").font(.caption).foregroundStyle(.secondary)
            case .unrated(let url):
                Text(url.host ?? "This site").font(.title2.weight(.bold))
                Text("Outlet not rated. Sidewise only rates the outlets it reads, and this link is not from one of them.")
                    .font(.callout).foregroundStyle(.secondary)
            case .noLink:
                Text("No link to check").font(.title2.weight(.bold))
                Text("Share a web link and Sidewise will say how its outlet is rated.").font(.callout).foregroundStyle(.secondary)
            case .offline(let url):
                Text(url.host ?? "This site").font(.title2.weight(.bold))
                Text("Could not reach Sidewise to look up this outlet. Try again when you are online.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }
}
