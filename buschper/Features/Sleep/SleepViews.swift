import CoreData
import SwiftUI

/// Tab „Schlaf“ (SPEC 11.5).
struct SleepView: View {
    @Environment(AppEnvironment.self) private var app

    @State private var range: ChartRange = .month
    @State private var nights: [NightRecord] = []
    @State private var isRefreshing = false
    @State private var didInitialRefresh = false

    private var lastNight: NightRecord? {
        nights.last { Calendar.current.isDateInToday($0.nightDate ?? .distantPast) }
    }

    private var chartNights: [NightRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return nights.filter { ($0.nightDate ?? .distantPast) >= start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let lastNight {
                        LastNightCard(night: lastNight)
                    } else if !isRefreshing {
                        VStack(alignment: .leading, spacing: 8) {
                            CardHeader(title: "Letschti Nacht", symbol: "moon.zzz.fill", color: Theme.sleep)
                            Text("Für die Nacht het Apple Health no kener Schlafdate. D Uhr i dr Nacht trage u dr Schlaf-Fokus mit Schlafplan ischalte – de chunnt's vo säuber.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .card(tint: Theme.sleep)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Schlafscore").font(.headline)
                            Spacer()
                            Picker("Zytruum", selection: $range) {
                                ForEach(ChartRange.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                        }
                        if chartNights.isEmpty {
                            Text("No kener Nächt uswärtet.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textTertiary)
                        } else {
                            SleepScoreChart(nights: chartNights, days: range.days,
                                            threshold: app.store.profile().badNightRules.absoluteThreshold)
                        }
                    }
                    .card(tint: Theme.sleep)

                    NavigationLink {
                        PatternsView()
                    } label: {
                        HStack {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundStyle(Theme.background)
                                .frame(width: 36, height: 36)
                                .background(Theme.sleep, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Muster").font(.headline)
                                Text("Was hanget bi dir mit schlächtem Schlaf zäme?")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nächt").font(.headline)
                        if nights.isEmpty {
                            Text(isRefreshing ? "Wärte us …" : "No kener Nächt.")
                                .foregroundStyle(Theme.textTertiary)
                        }
                        ForEach(Array(nights.reversed())) { night in
                            NavigationLink {
                                NightDetailView(night: night)
                            } label: {
                                NightRow(night: night)
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Theme.separator)
                        }
                    }
                    .card()

                    MedicalDisclaimer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Schlaf")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await refresh(days: 90) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Aui Nächt nöi uswärte")
                    }
                }
            }
            .refreshable { await refresh(days: 30) }
            .task(id: app.revision) { load() }
            .task {
                // Beim ersten Öffnen die letzten 30 Nächte auswerten, danach genügt
                // das Nachführen beim App-Start.
                guard !didInitialRefresh else { return }
                didInitialRefresh = true
                await refresh(days: 30)
            }
        }
    }

    private func load() {
        let end = DayMath.nextDay(of: Date())
        let start = Calendar.current.date(byAdding: .day, value: -90, to: end) ?? end
        nights = app.store.nights(from: start, to: end)
    }

    private func refresh(days: Int) async {
        isRefreshing = true
        await app.sleep.refresh(days: days)
        isRefreshing = false
        load()
    }
}

// MARK: - Bausteine

struct LastNightCard: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var night: NightRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Letschti Nacht", subtitle: timesText, symbol: "moon.zzz.fill", color: Theme.sleep)
            HStack(alignment: .bottom) {
                StatValue(value: "\(Int(night.score.rounded()))", caption: "Score")
                Spacer()
                StatValue(value: OnboardingView.hoursText(Int(night.asleepMinutes)), caption: "gschlafe", alignment: .trailing)
            }
            if night.hasStages {
                StageBar(night: night)
            }
            if night.isBad {
                BadgeView(text: "Schlächti Nacht", color: Theme.bad, systemImage: "exclamationmark.triangle.fill")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Wie guet hesch gschlafe?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                StarRating(rating: Binding(
                    get: { night.ratingValue ?? 0 },
                    set: { value in
                        night.ratingValue = value
                        app.sleep.classify(night)
                        app.dataDidChange()
                    }
                ))
            }
        }
        .card(tint: Theme.sleep)
    }

    private var timesText: String? {
        guard let onset = night.sleepOnset, let wake = night.wakeTime else { return nil }
        return "\(onset.formatted(date: .omitted, time: .shortened)) – \(wake.formatted(date: .omitted, time: .shortened))"
    }
}

struct NightRow: View {
    @ObservedObject var night: NightRecord

    var body: some View {
        HStack(spacing: 12) {
            Text("\(Int(night.score.rounded()))")
                .font(.headline)
                .monospacedDigit()
                .frame(width: 44, height: 44)
                .background((night.isBad ? Theme.bad : Theme.sleep).opacity(0.18), in: Circle())
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(night.nightDate?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) ?? "")
                        .font(.subheadline.weight(.semibold))
                    if night.isBad {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.bad)
                            .accessibilityLabel("Schlächti Nacht")
                    }
                    if night.excluded {
                        Text("usgschlosse").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
                Text(OnboardingView.hoursText(Int(night.asleepMinutes)))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array(night.factors).sorted { $0.rawValue < $1.rawValue }) { factor in
                    Image(systemName: factor.symbolName)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityLabel(factor.label)
                }
            }
            if let rating = night.ratingValue {
                Text(String(repeating: "★", count: rating))
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Schlafphasen als gestapelter Balken mit Beschriftung.
struct StageBar: View {
    let night: NightRecord

    private var parts: [(label: String, minutes: Double, color: Color)] {
        [
            ("Tief", night.deepMinutes, Theme.sleep),
            ("REM", night.remMinutes, Theme.sleep.opacity(0.65)),
            ("Kern", night.coreMinutes, Theme.sleep.opacity(0.35)),
            ("Wach", night.awakeMinutes, Theme.textTertiary)
        ]
    }

    var body: some View {
        let total = max(1, parts.reduce(0) { $0 + $1.minutes })
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(parts.indices, id: \.self) { index in
                        let part = parts[index]
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(part.color)
                            .frame(width: max(0, (geometry.size.width - 6) * part.minutes / total))
                    }
                }
            }
            .frame(height: 10)
            HStack(spacing: 10) {
                ForEach(parts.indices, id: \.self) { index in
                    let part = parts[index]
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(part.color).frame(width: 8, height: 8)
                        Text("\(part.label) \(Int(part.minutes.rounded())) min")
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StarRating: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = rating == value ? 0 : value
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(value <= rating ? Theme.warning : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value) Stärn")
            }
        }
    }
}
