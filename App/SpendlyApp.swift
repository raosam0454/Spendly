import SwiftUI
import SwiftData

@main
struct SpendlyApp: App {
    @StateObject private var settingsViewModel = SettingsViewModel()

    init() {
        // nav bar styling
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor(red: 26/255, green: 53/255, blue: 96/255, alpha: 1)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 26/255, green: 53/255, blue: 96/255, alpha: 1)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 26/255, green: 53/255, blue: 96/255, alpha: 1)

        // tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 26/255, green: 53/255, blue: 96/255, alpha: 1)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TransactionModel.self, BudgetModel.self, CategoryModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsViewModel)
                .onAppear {
                    // generate any recurring transactions that are due
                    let ctx = sharedModelContainer.mainContext
                    let ds = DataService(modelContext: ctx)
                    ds.processRecurringTransactions()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
