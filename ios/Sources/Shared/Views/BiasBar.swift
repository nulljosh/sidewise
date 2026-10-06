import SwiftUI

extension Side {
    var color: Color {
        switch self {
        case .left: return Color(red: 0.16, green: 0.31, blue: 0.55)
        case .center: return Color.secondary
        case .right: return Color(red: 0.75, green: 0.23, blue: 0.17)
        }
    }
    var label: String { rawValue.capitalized }
}

/// Proportional left/center/right coverage for one story.
struct BiasBar: View {
    let left: Int, center: Int, right: Int
    var height: CGFloat = 5

    init(story: Story) {
        self.init(left: story.count(.left), center: story.count(.center), right: story.count(.right))
    }

    init(left: Int, center: Int, right: Int, height: CGFloat = 5) {
        self.left = left; self.center = center; self.right = right; self.height = height
    }

    private func count(_ side: Side) -> Int { side == .left ? left : side == .center ? center : right }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Side.allCases, id: \.self) { side in
                    side.color.frame(width: width(side, total: geo.size.width))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityLabel(Side.allCases.map { "\($0.label) \(count($0))" }.joined(separator: ", "))
    }

    private func width(_ side: Side, total: CGFloat) -> CGFloat {
        let all = left + center + right
        guard all > 0 else { return 0 }
        return total * CGFloat(count(side)) / CGFloat(all)
    }
}

struct BlindspotTag: View {
    let side: Side

    var body: some View {
        Text("\(side.label)-only")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(side.color, lineWidth: 1))
            .foregroundStyle(side.color)
    }
}

/// Where one outlet sits on the five-step scale from left to right.
struct BiasScale: View {
    let bias: Int
    var showLabel = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(-2...2, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step == clamped ? color : Color.secondary.opacity(0.2))
                        .frame(height: 6)
                }
            }
            if showLabel {
                Text(biasLabel(bias)).font(.caption.weight(.semibold)).foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(biasLabel(bias))
    }

    private var clamped: Int { max(-2, min(2, bias)) }
    private var color: Color { (bias < 0 ? Side.left : bias > 0 ? Side.right : Side.center).color }
}
