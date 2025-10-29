import SwiftUI

private struct ScenarioOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
}

struct HomeView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Binding var showSettings: Bool
    @State private var selectedScenario: ScenarioOption?
    @State private var useCustomScenario = false
    @State private var customScenarioText: String = ""

    private static let defaultScenarios: [ScenarioOption] = [
        .init(
            title: "Misty Crossroads",
            subtitle: "A quiet fork in the forest at dusk.",
            prompt: """
            Genre: Atmospheric fantasy adventure.
            Tone: Reflective, grounded, lightly mysterious. Avoid modern slang.
            Opening premise: The traveler reaches a quiet crossroads at dusk, mist curling across each path.
            Cast: The traveler (narrator), an enigmatic guide named Ilya, and a fox-spirit called Kerren.
            Dialogue: Always format as Character Name: "Line." with each speaker on its own line. Include at least three exchanges mixed with descriptive exposition.
            Decision continuity: Treat each player choice as a committed action and narrate its immediate consequences in the next chapter.
            Anti-repetition: Never reuse earlier paragraphs—move forward with new imagery every chapter.
            """
        ),
        .init(
            title: "Clockwork City",
            subtitle: "Steam and gears power a city on the brink.",
            prompt: """
            Genre: Gaslamp fantasy with light intrigue.
            Tone: Curious, observant, with subtle tension.
            Opening premise: The protagonist arrives at a towering clockwork city whose heart has begun to falter.
            Cast: The engineer narrator, archivist Maeve, and a sentient automaton named Orin.
            Dialogue: When characters speak, use Character Name: "Line." format on separate lines. Aim for lively exchanges balanced with scene-setting detail.
            Decision continuity: Carry the player's chosen plan into the next beat and show how the city responds.
            Anti-repetition: Write only new scenes; never copy or lightly rephrase earlier prose.
            """
        ),
        .init(
            title: "Tideworn Archive",
            subtitle: "Ancient lore beneath a tidal monastery.",
            prompt: """
            Genre: Lyrical mystery with occult undertones.
            Tone: Contemplative, reverent, tinged with awe.
            Opening premise: Low tide reveals a hidden library carved into seaside cliffs, holding truths the world forgot.
            Cast: Scholar narrator, elder Sister Maris, and a curious apprentice named Leto.
            Dialogue: Present dialogue as Character Name: "Line." with generous line spacing. Weave the spoken lines between evocative environmental exposition.
            Decision continuity: Fold the chosen action into the new prose so the archive feels responsive to the protagonist's intent.
            Anti-repetition: Do not restate prior paragraphs; uncover fresh details with each turn.
            """
        )
    ]

    private let scenarios = Self.defaultScenarios

    init(showSettings: Binding<Bool>) {
        _showSettings = showSettings
        _selectedScenario = State(initialValue: Self.defaultScenarios.first)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                modelPickerCard
                scenarioPickerCard
                customScenarioCard
                startButton
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            if viewModel.availableModels.isEmpty && !viewModel.isLoadingModels {
                viewModel.refreshModels()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose Your Story Engine")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                Text("Select a model and starting prompt to begin weaving a bespoke adventure.")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(MonochromeButtonStyle(kind: .subtle))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modelPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Story Engine")
                .font(Theme.monoCaption())
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Label(viewModel.provider.displayName, systemImage: viewModel.provider == .ollama ? "server.rack" : "cloud")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            if viewModel.availableModels.isEmpty {
                if viewModel.provider == .ollama {
                    if viewModel.isLoadingModels {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(Theme.accent)
                            Text("Loading installed Ollama models…")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Button {
                            viewModel.refreshModels()
                        } label: {
                            Label("Refresh from Ollama", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .primary))

                        Text("No models found. Use the Ollama app or CLI to pull a model, then refresh.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if viewModel.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Add your Groq API key in Settings to unlock cloud models.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Choose a Groq model in Settings.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Label("Open Settings", systemImage: "gearshape")
                                .font(.callout.weight(.semibold))
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .subtle))
                    }
                }
            } else {
                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Theme.accent)

                if viewModel.provider == .ollama {
                    Button {
                        viewModel.refreshModels()
                    } label: {
                        Label("Check for new models", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                } else if viewModel.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("API key required", systemImage: "key.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .cardBackground()
    }

    private var scenarioPickerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scenarios")
                .font(Theme.monoCaption())
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(spacing: 12) {
                ForEach(scenarios) { option in
                    Button {
                        withAnimation {
                            selectedScenario = option
                            useCustomScenario = false
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text(option.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedScenario == option && !useCustomScenario ? Theme.surfaceElevated : Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selectedScenario == option && !useCustomScenario ? Theme.accent.opacity(0.6) : Theme.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardBackground()
    }

    private var customScenarioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Scenario")
                .font(Theme.monoCaption())
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Toggle(isOn: $useCustomScenario.animation()) {
                Text("Write your own opening prompt")
                    .foregroundStyle(Theme.textPrimary)
            }
            .toggleStyle(.switch)

            if useCustomScenario {
                TextEditor(text: $customScenarioText)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.divider, lineWidth: 1)
                    )
                    .font(Theme.bodyFont())
                    .foregroundStyle(Theme.textPrimary)
            } else {
                Text("Prefer a curated starting point? Toggle this on to craft your own scene.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardBackground()
    }

    private var startButton: some View {
        Button(action: startAdventure) {
            Label("Start Adventure", systemImage: "book.fill")
                .font(.title3.weight(.semibold))
        }
        .buttonStyle(MonochromeButtonStyle(kind: .primary))
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(!canStart)
        .opacity(canStart ? 1 : 0.6)
    }

    private var canStart: Bool {
        guard !viewModel.isLoadingModels else { return false }
        guard !viewModel.selectedModel.isEmpty else { return false }
        if useCustomScenario {
            return !customScenarioText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedScenario != nil
    }

    private func startAdventure() {
        let scenarioText: String?
        if useCustomScenario {
            scenarioText = customScenarioText
        } else {
            scenarioText = selectedScenario?.prompt
        }
        viewModel.beginSession(scenario: scenarioText)
    }
}

#Preview {
    HomeView(showSettings: Binding.constant(false))
        .environmentObject(GameViewModel())
}
