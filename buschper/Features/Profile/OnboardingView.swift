import CoreData
import SwiftUI

/// Ersteinrichtung (SPEC 4.1): Health verbinden, Profil aus Health vorausfüllen,
/// Ziel wählen.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var app
    @ObservedObject var profile: Profile
    var onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome, health, body, goal, done
    }

    @State private var step: Step = .welcome
    @State private var isConnecting = false
    @State private var healthWeight: Double?
    @State private var prefilledFromHealth = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progress
                ScrollView {
                    content
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
            .screenBackground()
            .interactiveDismissDisabled()
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Theme.accent : Theme.track)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .health: healthStep
        case .body: bodyStep
        case .goal: goalStep
        case .done: doneStep
        }
    }

    // MARK: - Schritte

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Grüessech bi buschper")
                .font(.largeTitle.weight(.bold))
            Text("buschper hiuft dir, Ässe, Trinke, Bewegig, Gwicht u Schlaf im Blick z haa – u usezfinde, was dir dr Schlaf verdirbt.")
                .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 12) {
                featureRow("fork.knife", Theme.nutrition, "Ässe u Trinke erfasse")
                featureRow("figure.walk", Theme.activity, "Bewegig us Apple Health")
                featureRow("scalemass.fill", Theme.weight, "Gwicht im Verlouf")
                featureRow("moon.zzz.fill", Theme.sleep, "Schlaf uswärte")
            }
            .card()
            Text("I paar Schritt isch aues igrichtet.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func featureRow(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.background)
                .frame(width: 32, height: 32)
                .background(color, in: Circle())
            Text(text)
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apple Health")
                .font(.largeTitle.weight(.bold))
            Text("buschper list us Health, was d Uhr oder d Waag misst, u schrybt dyni Iiträg zrügg, damit aues a eim Ort isch.")
                .foregroundStyle(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Läse").font(.headline)
                bullet("Aktivkalorie, Schritt, Trainings")
                bullet("Gwicht, Grössi, Geburtsdatum, Gschlächt")
                bullet("Schlaf mit Schlafphase")
                Text("Schrybe").font(.headline).padding(.top, 6)
                bullet("Mahlzyte mit Nährwärt, Wasser")
                bullet("Gwicht u Trainings, wo du vo Hand erfasst")
            }
            .card(tint: Theme.activity)

            Text("Du chasch jedi Berächtigung speter i dr Health-App ändere. buschper schickt nüt a Dritti.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)

            if prefilledFromHealth {
                Label("Aagabe us Health übernoh", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.good)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(BulletLabelStyle())
            .foregroundStyle(Theme.textSecondary)
    }

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Über di")
                .font(.largeTitle.weight(.bold))
            Text(prefilledFromHealth
                 ? "Das het buschper us Health übernoh. Bitte prüefe u ergänze."
                 : "Die Aagabe bruucht buschper für dy Grundumsatz.")
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 14) {
                Picker("Gschlächt", selection: Binding(get: { profile.sex }, set: { profile.sex = $0 })) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                DatePicker(
                    "Geburtsdatum",
                    selection: Binding(
                        get: { profile.birthDate ?? Calendar.current.date(byAdding: .year, value: -40, to: Date()) ?? Date() },
                        set: { profile.birthDate = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )

                NumberField(title: "Grössi", value: $profile.heightCm, unit: "cm", fractionDigits: 0)

                NumberField(title: "Gwicht", value: $profile.fallbackWeightKg, unit: "kg")
            }
            .card()

            Text("S Gwicht chunnt spöter automatisch us Health oder vo dyne Iiträg. Dä Wärt hie gilt nume, solang no keis bekannt isch.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Dys Ziel")
                .font(.largeTitle.weight(.bold))

            VStack(alignment: .leading, spacing: 14) {
                Picker("Ziel", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                    ForEach(WeightGoal.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                NumberField(
                    title: "Abschlag pro Tag",
                    value: Binding(
                        get: { profile.offset(for: profile.goal) },
                        set: { profile.setOffset($0, for: profile.goal) }
                    ),
                    unit: "kcal",
                    fractionDigits: 0
                )
                Text("Minus heisst weniger ässe als verbrucht. Abnäh −500, haute 0, zuenäh +300 sy d Vorgabe.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .card(tint: Theme.nutrition)

            VStack(alignment: .leading, spacing: 10) {
                Text("Bewegigsprofil")
                    .font(.headline)
                Text("Gilt nume, we Health bis am Mittag kener Aktivkalorie liferet – z. B. we d Uhr nid treit isch.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Picker("Bewegigsprofil", selection: Binding(get: { profile.activityProfile }, set: { profile.activityProfile = $0 })) {
                    ForEach(ActivityProfile.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.menu)
                Text(profile.activityProfile.explanation)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card(tint: Theme.activity)

            VStack(spacing: 14) {
                Stepper(value: Binding(get: { Int(profile.sleepGoalMinutes) }, set: { profile.sleepGoalMinutes = Int32($0) }),
                        in: 300...720, step: 15) {
                    LabeledValueRow(label: "Schlafziel") {
                        Text(Self.hoursText(Int(profile.sleepGoalMinutes)))
                            .monospacedDigit()
                    }
                }
                Stepper(value: Binding(get: { Int(profile.stepGoal) }, set: { profile.stepGoal = Int32($0) }),
                        in: 2000...30000, step: 500) {
                    LabeledValueRow(label: "Schrittziel") {
                        Text(NumberText.grouped(Double(profile.stepGoal)))
                            .monospacedDigit()
                    }
                }
            }
            .card()
        }
    }

    private var doneStep: some View {
        let bmr = profile.basalMetabolicRate(weightKg: healthWeight ?? profile.fallbackWeightKg)
        return VStack(alignment: .leading, spacing: 18) {
            Text("Parat!")
                .font(.largeTitle.weight(.bold))
            VStack(alignment: .leading, spacing: 12) {
                LabeledValueRow(label: "Grundumsatz") {
                    Text("\(NumberText.kcal(bmr)) kcal").monospacedDigit()
                }
                LabeledValueRow(label: "Ziel-Abschlag") {
                    Text("\(NumberText.kcal(profile.goalOffset)) kcal").monospacedDigit()
                }
                Text("Dy Tagesbudget isch dr Grundumsatz plus d Aktivkalorie, wo du im Louf vom Tag verbrennsch, plus dä Abschlag. Am Morge isch es drum knapp u wachst mit jedem Schritt.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card(tint: Theme.nutrition)
            Text("Aues chasch speter under „Ig“ ändere.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Fusszeile

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Zrügg") {
                    withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .welcome }
                }
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if step == .health && !prefilledFromHealth {
                Button("Später") { advance() }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 8)
            }
            Button {
                primaryAction()
            } label: {
                if isConnecting {
                    ProgressView()
                } else {
                    Text(primaryTitle).fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(isConnecting)
        }
        .padding(20)
        .background(Theme.surface.opacity(0.6))
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Los"
        case .health: return prefilledFromHealth ? "Wyter" : "Mit Health verbinde"
        case .body, .goal: return "Wyter"
        case .done: return "Fertig"
        }
    }

    private func primaryAction() {
        switch step {
        case .health where !prefilledFromHealth:
            Task { await connectHealth() }
        case .done:
            profile.onboardingCompleted = true
            profile.updatedAt = Date()
            app.dataDidChange()
            onFinish()
        default:
            advance()
        }
    }

    private func advance() {
        withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .done }
    }

    private func connectHealth() async {
        isConnecting = true
        defer { isConnecting = false }
        _ = await app.health.requestAuthorization()
        let data = await app.health.profileData()
        if let birthDate = data.birthDate { profile.birthDate = birthDate }
        if let sex = data.sex { profile.sex = sex }
        if let height = data.heightCm, height > 0 { profile.heightCm = height.rounded() }
        if let weight = data.latestWeightKg, weight > 0 {
            profile.fallbackWeightKg = (weight * 10).rounded() / 10
            healthWeight = weight
        }
        prefilledFromHealth = true
        app.store.save()
        advance()
    }

    static func hoursText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

/// Aufzählungspunkt: kleiner Punkt statt grosses Symbol.
struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
            configuration.title
        }
    }
}
