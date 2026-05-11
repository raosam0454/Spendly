import Foundation
import SwiftUI

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct DailySpendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var categoryChartData: [ChartDataPoint] = []
    @Published var dailyTrendData: [DailySpendPoint] = []
    @Published var totalIncome: Double = 0
    @Published var totalExpenses: Double = 0
    @Published var previousMonthExpenses: Double = 0
    @Published var highestSpendingDay: (Date, Double)? = nil

    private let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
        NotificationCenter.default.addObserver(
            forName: .spendlyDataCleared, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.load() }
        }
        NotificationCenter.default.addObserver(
            forName: .spendlyTransactionChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.load() }
        }
    }

    func load() {
        let txs = dataService.fetchTransactions(for: selectedMonth)

        totalIncome = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        totalExpenses = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

        // spending by category for bar chart
        let spendingByCat = dataService.spendingByCategory(for: selectedMonth)
        categoryChartData = spendingByCat.map { (cat, amount) in
            ChartDataPoint(label: cat.name, value: amount, color: cat.color)
        }

        // daily trend
        let daily = dataService.dailySpending(forLast: 30)
        dailyTrendData = daily.map { DailySpendPoint(date: $0.0, amount: $0.1) }
        highestSpendingDay = daily.max(by: { $0.1 < $1.1 })

        // previous month for comparison
        if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            let prevTxs = dataService.fetchTransactions(for: prevMonth)
            previousMonthExpenses = prevTxs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        }
    }

    var monthOverMonthChange: Double {
        guard previousMonthExpenses > 0 else { return 0 }
        return ((totalExpenses - previousMonthExpenses) / previousMonthExpenses) * 100
    }

    var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonth)
    }
}
