//
//  DashboardViewModel.swift
//  Spendly
//
//  Created by Sumangala Rao on 5/5/2026.
//
import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var budgets: [Budget] = []

    private let dataService: DataService
    private var observers: [NSObjectProtocol] = []
    // O(1) category lookups instead of O(n) linear scan each time
    private var categoryMap: [UUID: Category] = [:]

    init(dataService: DataService) {
        self.dataService = dataService

        let t1 = NotificationCenter.default.addObserver(
            forName: .spendlyDataCleared, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.load() }
        }
        let t2 = NotificationCenter.default.addObserver(
            forName: .spendlyTransactionChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.load() }
        }
        observers = [t1, t2]
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func load() {
        categories = dataService.fetchCategories()
        categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        budgets = dataService.fetchBudgets()
        transactions = dataService.fetchTransactions(for: selectedMonth)
    }

    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    // categories where spending is 80% or more of budget
    var overBudgetCategories: [(Category, Double, Double)] {
        let monthly = budgets.filter {
            Calendar.current.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        }
        return monthly.compactMap { budget in
            guard let cat = categories.first(where: { $0.id == budget.categoryID }) else { return nil }
            let spent = transactions
                .filter { $0.type == .expense && $0.categoryID == budget.categoryID }
                .reduce(0) { $0 + $1.amount }
            let pct = budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0
            return pct >= 0.8 ? (cat, spent, budget.monthlyLimit) : nil
        }
        .sorted { ($0.1 / $0.2) > ($1.1 / $1.2) }
        .prefix(3)
        .map { $0 }
    }

    // health score rings data
    var savingsProgress: Double {
        guard totalIncome > 0 else { return 0 }
        let saved = max(0, totalIncome - totalExpenses)
        return min(saved / totalIncome, 1.0)
    }

    // returns average fraction SPENT across all budgeted categories (0 = nothing spent, 1 = all maxed)
    // the ring fills up as you spend — health score uses (1 - budgetProgress)
    var budgetProgress: Double {
        let monthlyBudgets = budgets.filter {
            Calendar.current.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        }
        guard !monthlyBudgets.isEmpty else { return 0 }

        var totalRatio = 0.0
        for b in monthlyBudgets {
            let spent = transactions
                .filter { $0.type == .expense && $0.categoryID == b.categoryID }
                .reduce(0) { $0 + $1.amount }
            let spentRatio = b.monthlyLimit > 0 ? min(spent / b.monthlyLimit, 1.0) : 0
            totalRatio += spentRatio
        }
        return totalRatio / Double(monthlyBudgets.count)
    }

    var loggingProgress: Double {
        // how many of the last 7 days have at least one transaction logged
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let allTxs = dataService.fetchTransactions()
        var daysLogged = 0
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: -i, to: today) {
                let hasEntry = allTxs.contains { calendar.isDate($0.date, inSameDayAs: day) }
                if hasEntry { daysLogged += 1 }
            }
        }
        return Double(daysLogged) / 7.0
    }

    // weighted score out of 100 — budget contribution uses remaining headroom, not spent ratio
    var healthScore: Int {
        let s = savingsProgress * 40
        let b = (1.0 - budgetProgress) * 35
        let l = loggingProgress * 25
        return min(100, Int(s + b + l))
    }

    func categoryName(for id: UUID) -> String { categoryMap[id]?.name ?? "Unknown" }
    func categoryColor(for id: UUID) -> Color  { categoryMap[id]?.color ?? .gray }
    func categoryIcon(for id: UUID) -> String  { categoryMap[id]?.iconName ?? "circle" }

    func changeMonth(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) else { return }
        selectedMonth = newDate
        load()
    }

    var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonth)
    }
}
