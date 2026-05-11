//
//  BudgetsView.swift
//  Spendly
//
//  Created by Dhairya Shah on 5/5/2026.
//

import Foundation
import SwiftUI
import SwiftData

// preset budget templates for new users
// NOTE: limit values are example amounts — adjust them to match your local currency after applying
struct BudgetTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let currencyNote: String     // shown in UI so users know to adjust for their currency
    let limits: [String: Double] // category name -> monthly limit (example values, AUD-based)
}

let budgetTemplates: [BudgetTemplate] = [
    BudgetTemplate(
        name: "Broke Uni Student",
        description: "tight budget for when money is low",
        currencyNote: "Example amounts — adjust for your currency",
        limits: [
            "Food & Dining": 50, "Transport": 30, "Shopping": 20,
            "Entertainment": 15, "Education": 10, "Health": 15
        ]
    ),
    BudgetTemplate(
        name: "Part-time Worker",
        description: "earning a bit but still careful",
        currencyNote: "Example amounts — adjust for your currency",
        limits: [
            "Food & Dining": 120, "Transport": 60, "Shopping": 50,
            "Entertainment": 40, "Education": 20, "Health": 30,
            "Bills & Utilities": 80
        ]
    ),
    BudgetTemplate(
        name: "Full-time Earner",
        description: "comfortable but keeping track",
        currencyNote: "Example amounts — adjust for your currency",
        limits: [
            "Food & Dining": 300, "Transport": 150, "Shopping": 200,
            "Entertainment": 100, "Education": 50, "Health": 80,
            "Bills & Utilities": 200, "Rent": 500
        ]
    )
]

@MainActor
final class BudgetsViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var budgets: [Budget] = []
    @Published var transactions: [Transaction] = []
    @Published var selectedMonth: Date = Date()
    @Published var errorMessage: String? = nil
    @Published var selectedCategory: Category? = nil

    private var dataService: DataService
    private let notificationService: NotificationService
    private var observers: [NSObjectProtocol] = []

    init(dataService: DataService, notificationService: NotificationService = .shared) {
        self.dataService = dataService
        self.notificationService = notificationService
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
        budgets = dataService.fetchBudgets()
        transactions = dataService.fetchTransactions(for: selectedMonth)
    }

    func budget(for categoryID: UUID) -> Budget? {
        budgets.first {
            $0.categoryID == categoryID &&
            Calendar.current.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    func spentAmount(for categoryID: UUID) -> Double {
        transactions
            .filter { $0.type == .expense && $0.categoryID == categoryID }
            .reduce(0) { $0 + $1.amount }
    }

    func progressFraction(for categoryID: UUID) -> Double {
        guard let b = budget(for: categoryID), b.monthlyLimit > 0 else { return 0 }
        return min(spentAmount(for: categoryID) / b.monthlyLimit, 1.0)
    }

    func progressColor(for categoryID: UUID) -> Color {
        let pct = progressFraction(for: categoryID)
        if pct >= 1.0 { return .red }
        if pct >= 0.8 { return .orange }
        return .green
    }

    func addOrUpdateBudget(categoryID: UUID, limit: Double) {
        do {
            if let existing = budget(for: categoryID) {
                let updated = Budget(id: existing.id, categoryID: categoryID,
                                    monthlyLimit: limit, month: selectedMonth)
                try dataService.updateBudget(updated)
            } else {
                let newBudget = Budget(categoryID: categoryID, monthlyLimit: limit, month: selectedMonth)
                try dataService.addBudget(newBudget)
            }
            load()
            Task { await checkAndNotify(for: categoryID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBudget(for categoryID: UUID) {
        guard let b = budget(for: categoryID) else { return }
        do {
            try dataService.deleteBudget(id: b.id)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transactionsFor(category: Category) -> [Transaction] {
        transactions.filter { $0.type == .expense && $0.categoryID == category.id }
    }

    // apply a template - matches category names to existing categories
    func applyTemplate(_ template: BudgetTemplate) {
        for (catName, limit) in template.limits {
            if let cat = categories.first(where: { $0.name == catName }) {
                addOrUpdateBudget(categoryID: cat.id, limit: limit)
            }
        }
        load()
    }

    // check if any budgets have been set for this month
    var hasBudgetsThisMonth: Bool {
        budgets.contains {
            Calendar.current.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonth)
    }

    private func checkAndNotify(for categoryID: UUID) async {
        guard let cat = categories.first(where: { $0.id == categoryID }),
              let b = budget(for: categoryID), b.monthlyLimit > 0 else { return }
        let pct = spentAmount(for: categoryID) / b.monthlyLimit
        if pct >= 1.0 {
            await notificationService.scheduleBudgetAlert(categoryName: cat.name,
                                                          percentage: 100, categoryID: categoryID)
        } else if pct >= 0.8 {
            await notificationService.scheduleBudgetAlert(categoryName: cat.name,
                                                          percentage: 80, categoryID: categoryID)
        }
    }
}
