import SwiftUI

/// Das Blatt hinter „＋“: Ässe · Trinke · Gwicht · Training (SPEC 2).
struct QuickAddSheet: View {
    enum Target: String, Identifiable {
        case food, drink, weight, workout
        var id: String { rawValue }
    }

    @State private var target: Target?

    var body: some View {
        VStack(spacing: 20) {
            Text("Erfasse")
                .font(.headline)
                .padding(.top, 20)
            HStack(spacing: 12) {
                button(.food, "Ässe", "fork.knife", Theme.nutrition)
                button(.drink, "Trinke", "drop.fill", Theme.fluid)
                button(.weight, "Gwicht", "scalemass.fill", Theme.weight)
                button(.workout, "Training", "figure.run", Theme.activity)
            }
            .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .sheet(item: $target) { target in
            destination(target)
        }
    }

    @ViewBuilder
    private func destination(_ target: Target) -> some View {
        switch target {
        case .food: AddFoodView()
        case .drink: QuickAddDestinations.drink()
        case .weight: QuickAddDestinations.weight()
        case .workout: QuickAddDestinations.workout()
        }
    }

    private func button(_ target: Target, _ title: String, _ symbol: String, _ color: Color) -> some View {
        Button {
            self.target = target
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.background)
                    .frame(width: 60, height: 60)
                    .background(color, in: Circle())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
