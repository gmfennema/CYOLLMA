import SwiftUI

struct GameExperienceView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @Binding var showSettings: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(showSettings: $showSettings)
                    .environmentObject(viewModel)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    .background(Theme.surface)
                    .overlay(
                        Rectangle()
                            .fill(Theme.divider)
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

                StoryView()
                    .environmentObject(viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                ChoiceButtons()
                    .environmentObject(viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 18)
                    .background(Theme.surface)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: -2)
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.danger)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button("Dismiss") { viewModel.errorMessage = nil }
                        .buttonStyle(MonochromeButtonStyle(kind: .subtle, compact: true))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.danger.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .transition(.move(edge: .top))
            }
        }
    }
}

#Preview {
    GameExperienceView(showSettings: Binding.constant(false))
        .environmentObject(GameViewModel())
}
