import Foundation

struct StoriesResponse: Decodable {
    let stories: [Story]
}

struct Story: Decodable, Identifiable {
    let title: String
    let sources: [Source]
    var id: String { title }

    struct Source: Decodable {
        let outlet: String
    }
}

@MainActor
final class StoriesFetcher: ObservableObject {
    @Published var stories: [Story] = []
    @Published var loading = true
    @Published var failed = false

    func load() async {
        loading = true
        failed = false
        guard let url = URL(string: "https://sidewise.heyitsmejosh.com/api/stories?limit=10") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(StoriesResponse.self, from: data)
            stories = decoded.stories
        } catch {
            failed = true
        }
        loading = false
    }
}
