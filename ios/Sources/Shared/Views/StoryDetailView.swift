import SwiftUI

struct StoryDetailView: View {
    let story: Story

    init(story: Story) { self.story = story.coherent }

    @EnvironmentObject var service: NewsService
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(story.title).font(.title3.weight(.semibold))
                    BiasBar(story: story)
                    HStack(spacing: 14) {
                        ForEach(Side.allCases, id: \.self) { side in
                            Label("\(story.count(side))", systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption)
                                .imageScale(.small)
                                .foregroundStyle(side.color)
                                .accessibilityLabel("\(side.label): \(story.count(side))")
                        }
                    }
                    if story.blindspot, let side = story.lonelySide {
                        Text("Blindspot — only \(side.label.lowercased())-leaning outlets are covering this.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            let comparison = Comparison(story)
            Section(comparison.isComparable ? "Side by side, left to right" : "Coverage") {
                if !comparison.isComparable, let only = comparison.entries.first {
                    Text("Only \(only.outletKey) has this so far, so there is nothing to compare yet. It will fill in as other outlets pick it up.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(comparison.entries) { source in
                    OutletCard(source: source)
                }
                if comparison.isComparable, !comparison.missingSides.isEmpty {
                    Text("No \(comparison.missingSides.map { $0.label.lowercased() }.joined(separator: " or ")) outlet has covered this yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Story")
        .toolbar {
            ShareLink(item: shareText) { Label("Share", systemImage: "square.and.arrow.up") }
            Button {
                service.toggleSave(story)
            } label: {
                Label(service.isSaved(story) ? "Saved" : "Save",
                      systemImage: service.isSaved(story) ? "bookmark.fill" : "bookmark")
            }
        }
    }

    /// Headline plus how the coverage splits, so the person you send it to sees the spread too.
    private var shareText: String {
        "\(story.title)\nCovered by \(story.outletCount) outlets: \(story.count(.left)) left, \(story.count(.center)) center, \(story.count(.right)) right.\nsidewise.heyitsmejosh.com"
    }
}
