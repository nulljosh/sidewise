import SwiftUI

/// The bias mix of what you opened this week. Computed on the device from your own taps.
struct DietView: View {
    @EnvironmentObject var service: NewsService

    var body: some View {
        let week = readsWithin(7, of: service.reads)
        let d = diet(service.reads)
        List {
            if d.total == 0 {
                Text("Open a few stories and your reading mix shows up here. It never leaves this device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Section("This week · \(d.total) opened") {
                    VStack(alignment: .leading, spacing: 12) {
                        BiasBar(left: d.left, center: d.center, right: d.right, height: 16)
                        ForEach(Side.allCases, id: \.self) { side in
                            HStack {
                                Circle().fill(side.color).frame(width: 8, height: 8)
                                Text(side.label)
                                Spacer()
                                Text("\(count(d, side)) · \(Int((d.share(side) * 100).rounded()))%")
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.vertical, 6)
                }
                if let lean = averageLean(week) {
                    Section("Average lean") {
                        VStack(alignment: .leading, spacing: 6) {
                            BiasScale(bias: Int(lean.rounded()))
                            Text(String(format: "%+.1f on a scale from -2 (left) to +2 (right).", lean))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                let top = topOutlets(week)
                if !top.isEmpty {
                    Section("Most opened") {
                        ForEach(top, id: \.outlet) { row in
                            HStack { Text(row.outlet); Spacer(); Text("\(row.count)").monospacedDigit().foregroundStyle(.secondary) }
                        }
                    }
                }
                if let blind = d.blindSide {
                    Section {
                        Text("You rarely open \(blind.label.lowercased())-leaning outlets. The Compare tab shows how they cover the same stories you read.")
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

    private func count(_ d: Diet, _ side: Side) -> Int {
        side == .left ? d.left : side == .center ? d.center : d.right
    }
}
