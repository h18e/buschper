import Foundation

/// Setzt aus den Schlaf-Rohdaten von Apple Health eine Nacht zusammen (SPEC 11).
///
/// Health enthält oft mehrere Quellen gleichzeitig (Uhr, iPhone, Schlaf-Apps), die
/// sich überlappen. Addieren würde doppelt zählen. Deshalb wird **eine** Quelle
/// gewählt: die mit Schlafphasen, sonst die mit der längsten Schlafzeit.
enum SleepNightBuilder {
    /// Die Nacht zu Tag D wird zwischen D−1 18:00 und D 14:00 gesucht.
    static let windowStartHour = 18
    static let windowEndHour = 14
    /// Liegen zwei Schlafabschnitte mehr als 2 h auseinander, gehören sie nicht
    /// zur selben Nacht (z. B. ein Nickerchen am Abend).
    static let clusterGap: TimeInterval = 2 * 3600
    /// Unter einer Stunde Schlaf gilt nicht als Nacht.
    static let minimumSleepMinutes = 60.0

    static func window(for nightDay: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: nightDay)
        let previous = DayMath.previousDay(of: day, calendar: calendar)
        let start = calendar.date(byAdding: .hour, value: windowStartHour, to: previous) ?? previous
        let end = calendar.date(byAdding: .hour, value: windowEndHour, to: day) ?? day
        return (start, end)
    }

    static func build(from samples: [HealthSleepSample]) -> SleepNight? {
        let bySource = Dictionary(grouping: samples, by: \.sourceId)
        let candidates = bySource.values.compactMap { night(from: $0) }
        let withStages = candidates.filter(\.hasStages)
        let pool = withStages.isEmpty ? candidates : withStages
        return pool.max { $0.asleepMinutes < $1.asleepMinutes }
    }

    /// Nacht aus den Daten einer einzigen Quelle.
    static func night(from samples: [HealthSleepSample]) -> SleepNight? {
        let asleepStages: Set<SleepStage> = [.asleep, .core, .deep, .rem]
        let asleep = samples
            .filter { asleepStages.contains($0.stage) && $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard !asleep.isEmpty else { return nil }

        // In Abschnitte teilen und den mit dem meisten Schlaf nehmen.
        var clusters: [[HealthSleepSample]] = [[asleep[0]]]
        for sample in asleep.dropFirst() {
            let lastEnd = clusters[clusters.count - 1].map(\.end).max() ?? sample.start
            if sample.start.timeIntervalSince(lastEnd) > clusterGap {
                clusters.append([sample])
            } else {
                clusters[clusters.count - 1].append(sample)
            }
        }
        guard let main = clusters.max(by: { minutes(merged($0)) < minutes(merged($1)) }) else { return nil }

        let intervals = merged(main)
        let asleepMinutes = minutes(intervals)
        guard asleepMinutes >= minimumSleepMinutes,
              let onset = intervals.first?.start,
              let wake = intervals.last?.end
        else { return nil }

        let hasStages = main.contains { [.core, .deep, .rem].contains($0.stage) }
        func stageMinutes(_ stage: SleepStage) -> Double? {
            guard hasStages else { return nil }
            return minutes(merged(main.filter { $0.stage == stage }))
        }

        let span = wake.timeIntervalSince(onset) / 60
        return SleepNight(
            sleepOnset: onset,
            wake: wake,
            asleepMinutes: asleepMinutes,
            deepMinutes: stageMinutes(.deep),
            remMinutes: stageMinutes(.rem),
            coreMinutes: stageMinutes(.core),
            awakeMinutes: max(0, span - asleepMinutes)
        )
    }

    /// Überlappende Abschnitte zusammenfassen.
    static func merged(_ samples: [HealthSleepSample]) -> [(start: Date, end: Date)] {
        let sorted = samples.sorted { $0.start < $1.start }
        var result: [(start: Date, end: Date)] = []
        for sample in sorted {
            if let last = result.last, sample.start <= last.end {
                result[result.count - 1].end = max(last.end, sample.end)
            } else {
                result.append((sample.start, sample.end))
            }
        }
        return result
    }

    static func minutes(_ intervals: [(start: Date, end: Date)]) -> Double {
        intervals.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) / 60 }
    }
}
