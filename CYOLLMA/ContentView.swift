import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: GameViewModel
    @State private var showSettings: Bool = false

    var body: some View {
        Group {
            if viewModel.isInSession {
                GameExperienceView(showSettings: $showSettings)
                    .environmentObject(viewModel)
                    .transition(.opacity)
            } else {
                HomeView(showSettings: $showSettings)
                    .environmentObject(viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isInSession)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsSheet(isPresented: $showSettings)
                .environmentObject(viewModel)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameViewModel())
}
