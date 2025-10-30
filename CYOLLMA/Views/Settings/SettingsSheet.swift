import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Binding var isPresented: Bool
    @State private var revealGroqKey: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    storySettingsSection
                    Divider()
                        .background(Theme.divider.opacity(0.4))
                    providerSection
                    Divider()
                        .background(Theme.divider.opacity(0.4))
                    groqSection
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Customize your story experience and model settings.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button("Done") {
                isPresented = false
            }
            .buttonStyle(MonochromeButtonStyle(kind: .subtle))
        }
    }

    private var storySettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Story Settings")
                .font(Theme.monoCaption())
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            // Temperature
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Temperature", systemImage: "flame")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f", viewModel.temperature))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Slider(value: $viewModel.temperature, in: 0.0...1.5, step: 0.1)
                    .tint(Theme.accent)
                Text("Controls randomness and creativity. Higher values produce more varied responses.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Content Rating
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Content Rating", systemImage: "hand.raised")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(contentRatingLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Slider(value: $viewModel.contentRating, in: 0.0...1.0, step: 0.1)
                    .tint(Theme.accent)
                Text("Adjust the maturity level of story content. Tame keeps content family-friendly, while Explicit allows mature themes.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Chapter Length
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Chapter Length", systemImage: "text.word.spacing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(chapterLengthLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Slider(value: $viewModel.chapterLength, in: 0.0...1.0, step: 0.1)
                    .tint(Theme.accent)
                Text("Control how long each chapter is. Short chapters are concise (~120 words), while Long chapters are more detailed (~300 words).")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Custom Story Instructions
            VStack(alignment: .leading, spacing: 8) {
                Label("Custom Story Instructions", systemImage: "pencil.line")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                
                TextEditor(text: $viewModel.customStoryInstructions)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.divider, lineWidth: 1)
                    )
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                
                Text("Add custom instructions to guide the story's tone, style, or themes. These will be included in every prompt.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var contentRatingLabel: String {
        if viewModel.contentRating < 0.3 {
            return "Tame"
        } else if viewModel.contentRating < 0.7 {
            return "Moderate"
        } else {
            return "Explicit"
        }
    }

    private var chapterLengthLabel: String {
        let words = Int(120 + (viewModel.chapterLength * 180))
        return "~\(words) words"
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Provider")
                .font(Theme.monoCaption())
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Picker("Provider", selection: $viewModel.provider) {
                ForEach(ModelProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.provider {
            case .ollama:
                Text("Use Ollama models running locally on your machine. Refresh the model list after installing new ones.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            case .groq:
                Text("Route requests through Groq’s hosted models. A valid Groq API key is required and charges may apply.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var groqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Groq API Key")
                    .font(Theme.monoCaption())
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer()

                Button {
                    revealGroqKey.toggle()
                } label: {
                    Label(revealGroqKey ? "Hide" : "Show", systemImage: revealGroqKey ? "eye.slash" : "eye")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))
            }

            Group {
                if revealGroqKey {
                    TextField("sk_live_...", text: $viewModel.groqAPIKey)
                } else {
                    SecureField("sk_live_...", text: $viewModel.groqAPIKey)
                }
            }
            .textFieldStyle(.roundedBorder)
#if os(iOS) || os(tvOS) || os(watchOS)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
#endif

            if viewModel.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Your key stays local to this app session. Paste a key generated from console.groq.com.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            } else {
                Text("Stored securely for this session only. Clear the field to stop using Groq.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    SettingsSheet(isPresented: Binding.constant(true))
        .environmentObject(GameViewModel())
}
