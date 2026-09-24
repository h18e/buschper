import AppIntents
import SwiftUI
import WidgetKit

/// Widget klein und mittel (SPEC 14).
@main
struct BuschperWidgetBundle: WidgetBundle {
    var body: some Widget {
        BuschperWidget()
    }
}

struct BuschperWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridge.widgetKind, provider: SnapshotProvider()) { entry in
            BuschperWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("buschper")
        .description("Kalorie übrig u Flüssigkeit vo hüt.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: context.isPreview ? .placeholder : WidgetBridge.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let entry = SnapshotEntry(date: now, snapshot: WidgetBridge.loadSnapshot(now: now))
        // Um Mitternacht neu, damit der neue Tag bei 0 beginnt.
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

/// „+250 ml“ direkt vom Homescreen, ohne die App zu öffnen.
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser erfasse"
    static var description = IntentDescription("Erfasst es Glas Wasser i buschper.")

    func perform() async throws -> some IntentResult {
        let ml = WidgetBridge.loadSnapshot()?.quickWaterMl ?? 250
        WidgetBridge.enqueueWater(ml: ml)
        return .result()
    }
}

/// Farben wie in der App (geprüft gegen die dunkle Fläche).
enum WidgetPalette {
    static let background = Color(red: 0.047, green: 0.051, blue: 0.063)
    static let track = Color.white.opacity(0.10)
    static let nutrition = Color(red: 0.215, green: 0.673, blue: 0.374)
    static let fluid = Color(red: 0.285, green: 0.587, blue: 0.902)
    static let carbs = Color(red: 0.702, green: 0.550, blue: 0.134)
    static let protein = Color(red: 0.000, green: 0.639, blue: 0.659)
    static let fat = Color(red: 0.815, green: 0.469, blue: 0.304)
    static let secondary = Color.white.opacity(0.62)
}

struct BuschperWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: medium(snapshot)
            default: small(snapshot)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "fork.knife")
                Text("buschper einisch öffne")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(WidgetPalette.secondary)
        }
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.kcalLeft >= 0 ? "No übrig" : "Drüber")
                .font(.caption)
                .foregroundStyle(WidgetPalette.secondary)
            (Text("\(Int(abs(snapshot.kcalLeft).rounded()))")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
             + Text(" kcal").font(.caption).foregroundColor(WidgetPalette.secondary))
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            bar(snapshot.kcalEaten / max(1, snapshot.kcalBudget), WidgetPalette.nutrition)
            HStack(spacing: 4) {
                Image(systemName: "drop.fill").foregroundStyle(WidgetPalette.fluid)
                Text("\(Int((snapshot.fluidFraction * 100).rounded())) %")
                    .monospacedDigit()
                Text(liters(snapshot.fluidMl)).foregroundStyle(WidgetPalette.secondary)
            }
            .font(.caption)
        }
        .foregroundStyle(.white)
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.kcalLeft >= 0 ? "No übrig" : "Drüber")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.secondary)
                Text("\(Int(abs(snapshot.kcalLeft).rounded())) kcal")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                macro("KH", snapshot.carbs, snapshot.carbsTarget, WidgetPalette.carbs)
                macro("Eiwiss", snapshot.protein, snapshot.proteinTarget, WidgetPalette.protein)
                macro("Fett", snapshot.fat, snapshot.fatTarget, WidgetPalette.fat)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill").foregroundStyle(WidgetPalette.fluid)
                    Text(liters(snapshot.fluidMl)).monospacedDigit()
                }
                .font(.headline)
                Text("\(Int((snapshot.fluidFraction * 100).rounded())) % vo \(liters(snapshot.fluidGoalMl))")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.secondary)
                bar(snapshot.fluidFraction, WidgetPalette.fluid)
                Spacer(minLength: 0)
                Button(intent: AddWaterIntent()) {
                    Label("+\(Int(snapshot.quickWaterMl)) ml", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(WidgetPalette.fluid)
            }
        }
        .foregroundStyle(.white)
    }

    private func macro(_ label: String, _ value: Double, _ target: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2).foregroundStyle(WidgetPalette.secondary)
                Spacer()
                Text("\(Int(value.rounded()))/\(Int(target.rounded())) g").font(.caption2).monospacedDigit()
            }
            bar(target > 0 ? value / target : 0, color)
        }
    }

    private func bar(_ fraction: Double, _ color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.track)
                Capsule().fill(color).frame(width: max(4, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 5)
    }

    private func liters(_ ml: Double) -> String {
        ml >= 1000 ? String(format: "%.1f l", ml / 1000) : "\(Int(ml.rounded())) ml"
    }
}
