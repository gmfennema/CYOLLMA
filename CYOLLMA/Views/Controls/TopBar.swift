import SwiftUI

struct TopBar: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.endSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical")
                    Text("Library")
                        .font(.headline)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary)
            .padding(.trailing, 4)

            Text("CYOA")
                .font(Theme.titleFont())
                .foregroundColor(Theme.textPrimary)
                .padding(.trailing, 12)

            modelSelector

            HStack {
                Image(systemName: "flame")
                    .foregroundStyle(Theme.textSecondary)
                Slider(value: $viewModel.temperature, in: 0.0...1.5, step: 0.1)
                    .tint(Theme.accent)
                Text(String(format: "%.1f", viewModel.temperature)).frame(width: 36, alignment: .trailing)
            }
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: 260)

            Spacer()

            Button("Restart Story") { viewModel.restartSession() }
                .buttonStyle(MonochromeButtonStyle())
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var modelSelector: some View {
        HStack(spacing: 8) {
            Label(viewModel.provider.displayName, systemImage: viewModel.provider == .ollama ? "server.rack" : "cloud")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            if viewModel.availableModels.isEmpty {
                if viewModel.provider == .ollama {
                    if viewModel.isLoadingModels {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.accent)
                            .frame(width: 26, height: 26)
                    } else {
                        Button("Load Models") { viewModel.refreshModels() }
                            .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))
                    }
                } else {
                    Text(viewModel.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add Groq API key in Settings" : "Choose a Groq model in Settings")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Theme.accent)

                if viewModel.provider == .ollama {
                    Button {
                        viewModel.refreshModels()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.textSecondary)
                    .help("Refresh installed models from Ollama")
                } else if viewModel.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "key.fill")
                        .foregroundStyle(Theme.danger)
                        .help("Groq API key required")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceElevated.opacity(0.6))
        )
    }
}

struct TopBar_Previews: PreviewProvider {
    static var previews: some View {
        TopBar(showSettings: Binding.constant(false)).environmentObject(GameViewModel())
            .padding()
            .background(Theme.background)
    }
}
