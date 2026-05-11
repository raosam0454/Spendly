import Foundation
import SwiftUI

@MainActor
final class TransactionsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var searchText: String = ""
    @Published var selectedCategoryFilter: UUID? = nil
    @Published var selectedTypeFilter: TransactionType? = nil
    @Published var dateRangeStart: Date? = nil
    @Published var dateRangeEnd: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var showDeleteConfirmation = false
    @Published var pendingDeleteID: UUID? = nil

    // undo stuff
    @Published var recentlyDeleted: Transaction? = nil
    @Published var showUndoToast = false
    private var undoTimer: Timer?

    private let dataService: DataService
    private var observers: [NSObjectProtocol] = []
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
        undoTimer?.invalidate()
    }

    func load() {
        transactions = dataService.fetchTransactions()
        categories = dataService.fetchCategories()
        categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    var filteredTransactions: [Transaction] {
        transactions.filter { tx in
            let matchSearch = searchText.isEmpty ||
                tx.title.localizedCaseInsensitiveContains(searchText)
            let matchCat = selectedCategoryFilter == nil || tx.categoryID == selectedCategoryFilter
            let matchType = selectedTypeFilter == nil || tx.type == selectedTypeFilter
            let matchStart = dateRangeStart == nil || tx.date >= dateRangeStart!
            let matchEnd = dateRangeEnd == nil || tx.date <= dateRangeEnd!
            return matchSearch && matchCat && matchType && matchStart && matchEnd
        }
    }

    var groupedTransactions: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { tx in
            calendar.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    // delete with undo - saves the transaction before removing it
    func deleteWithUndo(id: UUID) {
        guard let tx = transactions.first(where: { $0.id == id }) else { return }
        do {
            try dataService.deleteTransaction(id: id)
            recentlyDeleted = tx
            showUndoToast = true
            load()
            NotificationCenter.default.post(name: .spendlyTransactionChanged, object: nil)

            // auto dismiss the toast after 3 seconds
            undoTimer?.invalidate()
            undoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recentlyDeleted = nil
                    self?.showUndoToast = false
                }
            }
        } catch {
            errorMessage = "couldn't delete: \(error.localizedDescription)"
        }
    }

    func undoDelete() {
        guard let tx = recentlyDeleted else { return }
        do {
            try dataService.addTransaction(tx)
            recentlyDeleted = nil
            showUndoToast = false
            undoTimer?.invalidate()
            load()
            NotificationCenter.default.post(name: .spendlyTransactionChanged, object: nil)
        } catch {
            errorMessage = "undo failed: \(error.localizedDescription)"
        }
    }

    func confirmDelete(id: UUID) {
        pendingDeleteID = id
        showDeleteConfirmation = true
    }

    func executeDelete() {
        guard let id = pendingDeleteID else { return }
        deleteWithUndo(id: id)
        pendingDeleteID = nil
    }

    func categoryName(for id: UUID) -> String { categoryMap[id]?.name ?? "Unknown" }
    func categoryColor(for id: UUID) -> Color  { categoryMap[id]?.color ?? .gray }
    func categoryIcon(for id: UUID) -> String  { categoryMap[id]?.iconName ?? "circle" }

    func clearFilters() {
        selectedCategoryFilter = nil
        selectedTypeFilter = nil
        dateRangeStart = nil
        dateRangeEnd = nil
        searchText = ""
    }
}
