//
//  CYOLLMAApp.swift
//  CYOLLMA
//
//  Created by Gabe Fennema on 10/28/25.
//

import SwiftUI

@main
struct CYOLLMAApp: App {
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.automatic)
    }
}
