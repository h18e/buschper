import Charts
import SwiftUI

// Gestaltungsregeln (dataviz): dünne Linien (2 pt), Punkte ≥ 8 pt, Balken mit
// abgerundetem Ende, zurückhaltendes Raster, eine einzige y-Achse. Antippen oder
// Ziehen zeigt einen Hinweis mit Datum und Wert. Werte und Beschriftungen stehen
// in Textfarbe, nie in der Reihenfarbe.

private let dayFormat = Date.FormatStyle().day().month(.abbreviated)

/// Gemeinsamer Hinweis beim Antippen eines Datenpunkts.
struct ChartTooltip: View {
    let title: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(8)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.separator))
    }
}

/// Zurückhaltende Achsen für alle Graphen.
private struct QuietAxes: ViewModifier {
    let days: Int

    func body(content: Content) -> some View {
        content
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, days / 5))) { _ in
                    AxisGridLine().foregroundStyle(Theme.separator)
                    AxisValueLabel(format: dayFormat)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Theme.separator)
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
    }
}

private func sameDay(_ a: Date, _ b: Date) -> Bool {
    Calendar.current.isDate(a, inSameDayAs: b)
}

// MARK: - Gewicht

/// Gewicht: Tageswerte als Punkte, 7-Tage-Schnitt als Linie.
struct WeightChart: View {
    let daily: [DailyWeight]
    let average: [DailyWeight]
    let days: Int
    var target: Double?

    @State private var selected: Date?

    private var domain: ClosedRange<Double> {
        let values = daily.map(\.kg) + average.map(\.kg) + (target.map { [$0] } ?? [])
        guard let low = values.min(), let high = values.max() else { return 60...80 }
        return (low - 0.8)...(high + 0.8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(average) { point in
                    LineMark(x: .value("Tag", point.day, unit: .day), y: .value("Schnitt", point.kg))
                        .foregroundStyle(Theme.weight)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                ForEach(daily) { point in
                    PointMark(x: .value("Tag", point.day, unit: .day), y: .value("Gwicht", point.kg))
                        .foregroundStyle(Theme.weight.opacity(0.55))
                        .symbolSize(40)
                }
                if let target {
                    RuleMark(y: .value("Ziel", target))
                        .foregroundStyle(Theme.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Ziel").font(.caption2).foregroundStyle(Theme.textTertiary)
                        }
                }
                if let selected, let point = daily.first(where: { sameDay($0.day, selected) }) {
                    RuleMark(x: .value("Tag", point.day, unit: .day))
                        .foregroundStyle(Theme.textTertiary)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            ChartTooltip(
                                title: point.day.formatted(dayFormat),
                                value: "\(NumberText.oneDecimal(point.kg)) kg",
                                detail: average.first(where: { sameDay($0.day, point.day) })
                                    .map { "Schnitt \(NumberText.oneDecimal($0.kg)) kg" }
                            )
                        }
                }
            }
            .chartYScale(domain: domain)
            .chartXSelection(value: $selected)
            .modifier(QuietAxes(days: days))
            .frame(height: 150)

            HStack(spacing: 14) {
                legendDot("Tageswärt", Theme.weight.opacity(0.55))
                legendLine("7-Tage-Schnitt", Theme.weight)
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gwichtsverlouf")
        .accessibilityValue(daily.last.map { "Zletscht \(NumberText.oneDecimal($0.kg)) Kilo" } ?? "Kener Wärt")
    }
}

// MARK: - Schlaf

/// Schlafscore der letzten Nächte. Schlechte Nächte sind zusätzlich als Dreieck
/// markiert – Form statt nur Farbe.
struct SleepScoreChart: View {
    let nights: [NightRecord]
    let days: Int
    var threshold: Double = 60

    @State private var selected: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                RuleMark(y: .value("Gränze", threshold))
                    .foregroundStyle(Theme.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                ForEach(nights) { night in
                    if let date = night.nightDate {
                        LineMark(x: .value("Nacht", date, unit: .day), y: .value("Score", night.score))
                            .foregroundStyle(Theme.sleep)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Nacht", date, unit: .day), y: .value("Score", night.score))
                            .foregroundStyle(night.isBad ? Theme.bad : Theme.sleep)
                            .symbol(night.isBad ? BasicChartSymbolShape.triangle : BasicChartSymbolShape.circle)
                            .symbolSize(night.isBad ? 70 : 36)
                    }
                }
                if let selected, let night = nights.first(where: { sameDay($0.nightDate ?? .distantPast, selected) }),
                   let date = night.nightDate {
                    RuleMark(x: .value("Nacht", date, unit: .day))
                        .foregroundStyle(Theme.textTertiary)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            ChartTooltip(
                                title: date.formatted(dayFormat),
                                value: "Score \(Int(night.score.rounded()))",
                                detail: night.isBad ? "Schlächti Nacht" : OnboardingView.hoursText(Int(night.asleepMinutes))
                            )
                        }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXSelection(value: $selected)
            .modifier(QuietAxes(days: days))
            .frame(height: 150)

            HStack(spacing: 14) {
                legendLine("Score", Theme.sleep)
                HStack(spacing: 4) {
                    Image(systemName: "triangle.fill").font(.system(size: 8)).foregroundStyle(Theme.bad)
                    Text("Schlächti Nacht")
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Theme.textTertiary).frame(width: 12, height: 1)
                    Text("Gränze \(Int(threshold))")
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schlafscore-Verlouf")
        .accessibilityValue(nights.last.map { "Zletscht \(Int($0.score.rounded())) Pünkt" } ?? "Kener Nächt")
    }
}

// MARK: - Flüssigkeit

/// Flüssigkeit pro Tag als Balken, Ziel als gestrichelte Linie.
struct FluidChart: View {
    let history: [DailyValue]
    let goalMl: Double
    let days: Int

    @State private var selected: Date?

    var body: some View {
        Chart {
            ForEach(history) { day in
                BarMark(x: .value("Tag", day.day, unit: .day), y: .value("Flüssigkeit", day.value / 1000))
                    .foregroundStyle(Theme.fluid)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
            }
            RuleMark(y: .value("Ziel", goalMl / 1000))
                .foregroundStyle(Theme.textTertiary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            if let selected, let day = history.first(where: { sameDay($0.day, selected) }) {
                RuleMark(x: .value("Tag", day.day, unit: .day))
                    .foregroundStyle(Theme.textTertiary.opacity(0.5))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        ChartTooltip(title: day.day.formatted(dayFormat), value: NumberText.volume(day.value))
                    }
            }
        }
        .chartXSelection(value: $selected)
        .modifier(QuietAxes(days: days))
        .frame(height: 110)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flüssigkeit pro Tag")
    }
}

// MARK: - Legende

func legendDot(_ label: String, _ color: Color) -> some View {
    HStack(spacing: 4) {
        Circle().fill(color).frame(width: 8, height: 8)
        Text(label)
    }
}

func legendLine(_ label: String, _ color: Color) -> some View {
    HStack(spacing: 4) {
        Capsule().fill(color).frame(width: 14, height: 2)
        Text(label)
    }
}
