//
//  ViewModelFactory.swift
//  Spendly
//
//  Created by Sumangala Rao on 4/5/2026.
//
import Foundation
import SwiftData
import SwiftUI

// creates viewmodels so views dont need to know about DataService internals
// all viewmodels share a single DataService instance
@MainActor
struct ViewModelFactory {
    let modelContext: ModelContext
    let dataService: DataService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.dataService = DataService(modelContext: modelContext)
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(dataService: dataService)
    }

    func makeTransactionsViewModel() -> TransactionsViewModel {
        TransactionsViewModel(dataService: dataService)
    }

    func makeBudgetsViewModel() -> BudgetsViewModel {
        BudgetsViewModel(dataService: dataService)
    }

    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(dataService: dataService)
    }
}
