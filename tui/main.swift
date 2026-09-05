import Foundation
import SwiftTUI

// ponytail: fetches /api/stories, same live JSON the reader renders, no bias
// analysis logic to port since none exists locally — sources already carry a
// bias score from the API.

struct Source: Decodable { let outlet: String; let bias: Int }
struct Story: Decodable, Identifiable { var id: String { title }; let title: String; let sources: [Source] }
struct StoriesResponse: Decodable { let stories: [Story] }

let args = CommandLine.arguments.dropFirst()
let limit = args.first.flatMap { Int($0) } ?? 5

func fetchStories() async -> [Story] {
    guard let url = URL(string: "https://sidewise.heyitsmejosh.com/api/stories?limit=\(limit)") else { return [] }
    guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
    return (try? JSONDecoder().decode(StoriesResponse.self, from: data))?.stories ?? []
}

struct StoriesCard: View {
    let stories: [Story]

    var body: some View {
        VStack(alignment: .leading) {
            Text("sidewise").bold()
            if stories.isEmpty {
                Text("Could not reach sidewise.heyitsmejosh.com")
            } else {
                ForEach(stories) { s in
                    Text("\(s.title) (\(s.sources.count) outlets)")
                }
            }
        }
        .padding()
        .border()
    }
}

let semaphore = DispatchSemaphore(value: 0)
var stories: [Story] = []
Task {
    stories = await fetchStories()
    semaphore.signal()
}
semaphore.wait()

Application(rootView: StoriesCard(stories: stories)).start()
