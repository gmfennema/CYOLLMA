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
                Text("Switch between local Ollama models or Groq’s hosted models.")
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
