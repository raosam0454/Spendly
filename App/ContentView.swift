import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if settingsViewModel.isFaceIDEnabled && !isAuthenticated {
                LockScreenView(isAuthenticated: $isAuthenticated)
            } else {
                MainTabView()
            }
        }
    }
}

struct LockScreenView: View {
    @Binding var isAuthenticated: Bool
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.lockGradient.ignoresSafeArea()

            // leaf decorations on lock screen
            GeometryReader { geo in
                ZStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 90)).foregroundStyle(.white.opacity(0.07))
                        .rotationEffect(.degrees(-30))
                        .position(x: geo.size.width * 0.85, y: geo.size.height * 0.1)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 55)).foregroundStyle(.white.opacity(0.06))
                        .rotationEffect(.degrees(25))
                        .position(x: geo.size.width * 0.72, y: geo.size.height * 0.17)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 110)).foregroundStyle(.white.opacity(0.06))
                        .rotationEffect(.degrees(150))
                        .position(x: geo.size.width * 0.12, y: geo.size.height * 0.84)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 65)).foregroundStyle(.white.opacity(0.05))
                        .rotationEffect(.degrees(120))
                        .position(x: geo.size.width * 0.22, y: geo.size.height * 0.92)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72)).foregroundStyle(.white)
                Text("Spendly").font(.largeTitle.bold()).foregroundStyle(.white)
                Text("Unlock to continue").foregroundStyle(.white.opacity(0.8))
                if let error = errorMessage {
                    Text(error).foregroundStyle(.red.opacity(0.9))
                        .font(.caption).multilineTextAlignment(.center).padding(.horizontal)
                }
                Button {
                    Task { await authenticate() }
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .frame(maxWidth: .infinity).padding()
                        .background(.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 40)
                Spacer()
            }
            .onAppear { Task { await authenticate() } }
        }
    }

    private func authenticate() async {
        let result = await settingsViewModel.authenticate()
        switch result {
        case .success: isAuthenticated = true; errorMessage = nil
        case .failure(let msg): errorMessage = msg
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
            BudgetsView()
                .tabItem { Label("Budgets", systemImage: "chart.pie.fill") }
            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(AppTheme.mint)
    }
}
