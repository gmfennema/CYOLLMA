import SwiftUI

struct ChoiceButtons: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var isWriteInPresented = false
    @State private var writeInText: String = ""
    @State private var isDirectionPresented = false
    @State private var directionText: String = ""
    @FocusState private var writeInFocused: Bool
    @FocusState private var directionFocused: Bool

    private let controlColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let chapter = viewModel.story.currentChapter, chapter.selectedOptionId == nil {
                Text("Choose your next path")
                    .font(Theme.monoCaption())
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.isRefreshingChoices {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.accent)
                            Text("Refreshing options...")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    ForEach(Array(chapter.choices.enumerated()), id: \.element.id) { index, choice in
                        Button(action: { viewModel.choose(choice) }) {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Theme.accent)

                                Text(choice.label)
                                    .font(Theme.bodyFont())
                                    .foregroundStyle(Theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.surface.opacity(0.9))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.isRefreshingChoices)
                    }

                    if let direction = viewModel.pendingCreativeDirection, !direction.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Creative direction queued", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text(direction)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.surface.opacity(0.7))
                        )
                    }

                    LazyVGrid(columns: controlColumns, spacing: 12) {
                        Button {
                            viewModel.regenerateChoicesForCurrentChapter()
                        } label: {
                            Label("Refresh options", systemImage: "square.grid.2x2")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .subtle))
                        .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.isRefreshingChoices)

                        Button {
                            viewModel.regenerateCurrentChapter()
                        } label: {
                            Label("Regenerate chapter", systemImage: "arrow.clockwise")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .subtle))
                        .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.isRefreshingChoices)

                        Button {
                            writeInText = ""
                            isWriteInPresented = true
                        } label: {
                            Label("Write an action", systemImage: "pencil")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .subtle))
                        .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.isRefreshingChoices)

                        Button {
                            directionText = viewModel.pendingCreativeDirection ?? ""
                            isDirectionPresented = true
                        } label: {
                            Label("Help write chapter", systemImage: "lightbulb")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .subtle))
                        .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.isRefreshingChoices)
                    }
                }
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(Theme.textPrimary)
        .sheet(isPresented: $isWriteInPresented) {
            writeInSheet
        }
        .sheet(isPresented: $isDirectionPresented) {
            directionSheet
        }
    }

    private var writeInSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Describe your action")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            TextEditor(text: $writeInText)
                .frame(minHeight: 120)
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
                .focused($writeInFocused)

            HStack {
                Button("Cancel") {
                    isWriteInPresented = false
                }
                .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))

                Spacer()

                Button("Submit") {
                    let text = writeInText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    viewModel.submitWriteIn(text)
                    isWriteInPresented = false
                }
                .buttonStyle(MonochromeButtonStyle(kind: .primary, compact: true))
                .disabled(writeInText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .background(Theme.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                writeInFocused = true
            }
        }
    }

    private var directionSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Outline the next chapter")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Share the specific beats or tone you want the next chapter to cover. The model will weave it into fresh prose.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            TextEditor(text: $directionText)
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
                .focused($directionFocused)

            HStack {
                Button("Cancel") {
                    isDirectionPresented = false
                }
                .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))

                if viewModel.pendingCreativeDirection != nil {
                    Button("Remove guidance", role: .destructive) {
                        viewModel.clearCreativeDirection()
                        isDirectionPresented = false
                    }
                    .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))
                }

                Spacer()

                Button("Save direction") {
                    viewModel.setCreativeDirection(directionText)
                    isDirectionPresented = false
                }
                .buttonStyle(MonochromeButtonStyle(kind: .primary, compact: true))
            }
        }
        .padding(24)
        .background(Theme.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                directionFocused = true
            }
        }
    }
}

struct ChoiceButtons_Previews: PreviewProvider {
    static var previews: some View {
        ChoiceButtons().environmentObject(GameViewModel())
            .padding()
            .background(Theme.background)
    }
}
