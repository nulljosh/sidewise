import SwiftUI

/// How much of what you open leans left, center or right. Computed on the device from your own taps.
struct DietView: View {
    @EnvironmentObject var service: NewsService

    var body: some View {
        let d = diet(service.reads)
        List {
            if d.total == 0 {
                Text("Open a few stories and your reading mix shows up here. It never leaves this device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Section("Last 30 days · \(d.total) opened") {
                    ForEach(Side.allCases, id: \.self) { side in
                        VStack(spacing: 8) {
                            HStack {
                                Text(side.label)
                                Spacer()
                                Text("\(Int((d.share(side) * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary)
                            }
                            ProgressView(value: d.share(side)).tint(side.color)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
                if let blind = d.blindSide {
                    Section {
                        Text("You rarely open \(blind.label.lowercased())-leaning outlets. The Blindspots filter shows stories only the other side is covering.")
                            .font(.callout)
                    }
                }
                Section {
                    Button("Clear reading history", role: .destructive) { service.clearReads() }
                }
            }
        }
        .navigationTitle("My Diet")
    }
}
