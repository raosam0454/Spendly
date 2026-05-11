import Foundation
import SwiftData

@MainActor
final class DataService: ObservableObject {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        seedDefaultCategoriesIfNeeded()
    }

    // categories

    func fetchCategories() -> [Category] {
        let descriptor = FetchDescriptor<CategoryModel>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor))?.map(\.asStruct) ?? []
    }

    func addCategory(_ category: Category) throws {
        let existing = fetchCategories()
        let model = CategoryModel(from: category, sortOrder: existing.count)
        modelContext.insert(model)
        try modelContext.save()
    }

    func updateCategory(_ updated: Category) throws {
        let descriptor = FetchDescriptor<CategoryModel>()
        let all = try modelContext.fetch(descriptor)
        guard let model = all.first(where: { $0.id == updated.id }) else { return }
        model.name = updated.name
        model.iconName = updated.iconName
        model.colorHex = updated.colorHex
        try modelContext.save()
    }

    func deleteCategory(id: UUID) throws {
        let descriptor = FetchDescriptor<CategoryModel>()
        let all = try modelContext.fetch(descriptor)
        if let model = all.first(where: { $0.id == id }) {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    func reorderCategories(_ categories: [Category]) throws {
        let descriptor = FetchDescriptor<CategoryModel>()
        let all = try modelContext.fetch(descriptor)
        for (index, cat) in categories.enumerated() {
            if let model = all.first(where: { $0.id == cat.id }) {
                model.sortOrder = index
            }
        }
        try modelContext.save()
    }

    // transactions

    func fetchTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<TransactionModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.map(\.asStruct) ?? []
    }

    func fetchTransactions(for month: Date) -> [Transaction] {
        let all = fetchTransactions()
        return all.filter {
            Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
        }
    }

    func addTransaction(_ transaction: Transaction) throws {
        let model = TransactionModel(from: transaction)
        modelContext.insert(model)
        try modelContext.save()
    }

    func updateTransaction(_ updated: Transaction) throws {
        let descriptor = FetchDescriptor<TransactionModel>()
        let all = try modelContext.fetch(descriptor)
        guard let model = all.first(where: { $0.id == updated.id }) else { return }
        model.title = updated.title
        model.amount = updated.amount
        model.typeRaw = updated.type.rawValue
        model.categoryID = updated.categoryID
        model.date = updated.date
        model.notes = updated.notes
        model.recurrenceRaw = updated.recurrence.rawValue
        try modelContext.save()
    }

    func deleteTransaction(id: UUID) throws {
        let descriptor = FetchDescriptor<TransactionModel>()
        let all = try modelContext.fetch(descriptor)
        if let model = all.first(where: { $0.id == id }) {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    // budgets

    func fetchBudgets() -> [Budget] {
        let descriptor = FetchDescriptor<BudgetModel>()
        return (try? modelContext.fetch(descriptor))?.map(\.asStruct) ?? []
    }

    func fetchBudget(for categoryID: UUID, month: Date) -> Budget? {
        fetchBudgets().first {
            $0.categoryID == categoryID &&
            Calendar.current.isDate($0.month, equalTo: month, toGranularity: .month)
        }
    }

    func addBudget(_ budget: Budget) throws {
        let model = BudgetModel(from: budget)
        modelContext.insert(model)
        try modelContext.save()
    }

    func updateBudget(_ updated: Budget) throws {
        let descriptor = FetchDescriptor<BudgetModel>()
        let all = try modelContext.fetch(descriptor)
        guard let model = all.first(where: { $0.id == updated.id }) else { return }
        model.monthlyLimit = updated.monthlyLimit
        model.month = updated.month
        try modelContext.save()
    }

    func deleteBudget(id: UUID) throws {
        let descriptor = FetchDescriptor<BudgetModel>()
        let all = try modelContext.fetch(descriptor)
        if let model = all.first(where: { $0.id == id }) {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    // clear everything
    func clearAllData() throws {
        try modelContext.delete(model: TransactionModel.self)
        try modelContext.delete(model: BudgetModel.self)
        try modelContext.delete(model: CategoryModel.self)
        try modelContext.save()
        seedDefaultCategoriesIfNeeded()
    }

    // put default categories in if theres nothing there
    private func seedDefaultCategoriesIfNeeded() {
        let existing = fetchCategories()
        guard existing.isEmpty else { return }
        for (index, cat) in Category.defaults.enumerated() {
            let model = CategoryModel(from: cat, sortOrder: index)
            modelContext.insert(model)
        }
        try? modelContext.save()
    }

    // analytics helpers

    func spendingByCategory(for month: Date) -> [(Category, Double)] {
        let txs = fetchTransactions(for: month).filter { $0.type == .expense }
        let cats = fetchCategories()
        return cats.compactMap { cat in
            let total = txs
                .filter { $0.categoryID == cat.id }
                .reduce(0) { $0 + $1.amount }
            return total > 0 ? (cat, total) : nil
        }.sorted { $0.1 > $1.1 }
    }

    func dailySpending(forLast days: Int) -> [(Date, Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expenses = fetchTransactions().filter { $0.type == .expense }
        return (0..<days).compactMap { offset -> (Date, Double)? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = expenses
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return (day, total)
        }.reversed()
    }

    // check for recurring transactions and generate any that are due
    func processRecurringTransactions() {
        let all = fetchTransactions()
        let recurring = all.filter { $0.isRecurring }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for tx in recurring {
            let nextDate = calculateNextDate(from: tx.date, rule: tx.recurrence)
            guard let next = nextDate, next <= today else { continue }

            // check if we already have a transaction on that date with same title + amount
            let alreadyExists = all.contains { existing in
                existing.title == tx.title &&
                existing.amount == tx.amount &&
                existing.categoryID == tx.categoryID &&
                calendar.isDate(existing.date, inSameDayAs: next)
            }

            if !alreadyExists {
                let newTx = Transaction(
                    title: tx.title,
                    amount: tx.amount,
                    type: tx.type,
                    categoryID: tx.categoryID,
                    date: next,
                    notes: tx.notes,
                    recurrence: tx.recurrence
                )
                try? addTransaction(newTx)
                print("auto created recurring: \(newTx.title)")
            }
        }
    }

    private func calculateNextDate(from date: Date, rule: RecurrenceRule) -> Date? {
        let calendar = Calendar.current
        switch rule {
        case .none: return nil
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .fortnightly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}
