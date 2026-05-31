import SwiftUI

/// Animated circular progress ring — the satisfying beat when a meal saves.
struct CalorieRing: View {
    let consumed: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1.0)
    }

    private var remaining: Int { max(goal - consumed, 0) }
    private var over: Bool { consumed > goal }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 22)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: over
                            ? [.orange, .red]
                            : [.accentColor.opacity(0.7), .accentColor]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

            VStack(spacing: 4) {
                Text("\(consumed)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(consumed)))
                    .animation(.spring(response: 0.6), value: consumed)
                Text("/ \(goal) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(over ? "\(consumed - goal) over" : "\(remaining) left")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(over ? .orange : .accentColor)
                    .padding(.top, 2)
            }
        }
        .frame(width: 220, height: 220)
        .padding(.vertical, 8)
    }
}

#Preview {
    CalorieRing(consumed: 1450, goal: 2200)
}
