import SwiftUI
import Charts
import SwiftData

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AnalyticsContent(modelContext: modelContext)
    }
}

struct AnalyticsContent: View {
    @StateObject private var viewModel: AnalyticsViewModel
    @EnvironmentObject private var settings: SettingsViewModel

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(
            dataService: DataService(modelContext: modelContext)
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthPicker
                    summaryRow
                    barChartSection
                    lineChartSection
                    donutSection
                    monthComparisonCard
                    highestSpendingCard
                }
                .padding()
                .padding(.bottom, 80)
            }
            .background(AppBackground())
            .navigationTitle("Analytics")
            .onAppear { viewModel.load() }
        }
    }

    private var monthPicker: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2).foregroundStyle(.blue)
            }
            Spacer()
            Text(viewModel.monthLabel).font(.headline)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundStyle(.blue)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 14) {
            SummaryCard(title: "Income", amount: viewModel.totalIncome, color: .green, icon: "arrow.down.circle.fill")
            SummaryCard(title: "Expenses", amount: viewModel.totalExpenses, color: .red, icon: "arrow.up.circle.fill")
        }
    }

    // bar chart - spending by category
    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category").font(.headline)
            if viewModel.categoryChartData.isEmpty {
                Text("No expense data for this month.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 100)
            } else {
                Chart(viewModel.categoryChartData) { point in
                    BarMark(x: .value("Amount", point.value), y: .value("Category", point.label))
                        .foregroundStyle(point.color).cornerRadius(4)
                }
                .frame(height: CGFloat(max(viewModel.categoryChartData.count * 44, 120)))
                .chartXAxis {
                    AxisMarks(position: .bottom) { AxisValueLabel(format: .currency(code: settings.selectedCurrencyCode)) }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    // line chart - daily spending trend
    private var lineChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Spending (Last 30 Days)").font(.headline)
            if viewModel.dailyTrendData.allSatisfy({ $0.amount == 0 }) {
                Text("No spending data available.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 120)
            } else {
                Chart(viewModel.dailyTrendData) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Amount", point.amount))
                        .foregroundStyle(.blue).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.date), y: .value("Amount", point.amount))
                        .foregroundStyle(.blue.opacity(0.1)).interpolationMethod(.catmullRom)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisValueLabel(format: .currency(code: settings.selectedCurrencyCode)) }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    // donut chart - income vs expenses (BUG FIX: income legend was showing expenses amount)
    private var donutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expenses").font(.headline)
            let total = viewModel.totalIncome + viewModel.totalExpenses
            if total == 0 {
                Text("No data available.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 120)
            } else {
                HStack {
                    Chart {
                        SectorMark(angle: .value("Income", viewModel.totalIncome),
                                   innerRadius: .ratio(0.55), angularInset: 2).foregroundStyle(.green)
                        SectorMark(angle: .value("Expenses", viewModel.totalExpenses),
                                   innerRadius: .ratio(0.55), angularInset: 2).foregroundStyle(.red)
                    }
                    .frame(height: 160)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle().fill(.green).frame(width: 12, height: 12)
                            VStack(alignment: .leading) {
                                Text("Income").font(.caption).foregroundStyle(.secondary)
                                Text(viewModel.totalIncome, format: .currency(code: settings.selectedCurrencyCode))
                                    .font(.subheadline.bold())
                            }
                        }
                        HStack(spacing: 8) {
                            Circle().fill(.red).frame(width: 12, height: 12)
                            VStack(alignment: .leading) {
                                Text("Expenses").font(.caption).foregroundStyle(.secondary)
                                Text(viewModel.totalExpenses, format: .currency(code: settings.selectedCurrencyCode))
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    private var monthComparisonCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Month-over-Month").font(.headline)
                Text("vs previous month spending").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let change = viewModel.monthOverMonthChange
            VStack(alignment: .trailing) {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                    Text(String(format: "%.1f%%", abs(change)))
                }
                .font(.title3.bold())
                .foregroundStyle(change >= 0 ? .red : .green)
                Text(viewModel.previousMonthExpenses, format: .currency(code: settings.selectedCurrencyCode))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    @ViewBuilder
    private var highestSpendingCard: some View {
        if let (day, amount) = viewModel.highestSpendingDay, amount > 0 {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(.orange).font(.title2)
                VStack(alignment: .leading) {
                    Text("Highest Spending Day").font(.subheadline.weight(.medium))
                    Text(day, style: .date).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(amount, format: .currency(code: settings.selectedCurrencyCode))
                    .font(.headline.bold()).foregroundStyle(.orange)
            }
            .padding()
            .background(.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func changeMonth(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .month, value: offset, to: viewModel.selectedMonth) else { return }
        viewModel.selectedMonth = newDate
        viewModel.load()
    }
}
