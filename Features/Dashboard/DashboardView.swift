//
//  DashboardView.swift
//  Spendly
//
//  Created by Sumangala Rao on 5/5/2026.
//
import SwiftUI
import SwiftData

// wrapper to grab modelContext from environment
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DashboardContent(modelContext: modelContext)
    }
}

struct DashboardContent: View {
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showAddSheet = false
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: DashboardViewModel(
            dataService: DataService(modelContext: modelContext)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        monthPicker
                        summaryCards
                        healthRings
                        budgetWarnings
                        recentTransactions
                    }
                    .padding()
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                }
                .background(AppBackground())

                // floating add button
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(AppTheme.navBar)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Spendly")
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showAddSheet, onDismiss: { viewModel.load() }) {
                TransactionFormView(modelContext: modelContext, onSave: { viewModel.load() })
            }
        }
    }

    // month navigation
    private var monthPicker: some View {
        HStack {
            Button { viewModel.changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title2).foregroundStyle(.blue)
            }
            Spacer()
            Text(viewModel.monthLabel).font(.headline)
            Spacer()
            Button { viewModel.changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundStyle(.blue)
            }
            .disabled(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month))
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 14) {
            SummaryCard(title: "Income", amount: viewModel.totalIncome, color: .green, icon: "arrow.down.circle.fill")
            SummaryCard(title: "Expenses", amount: viewModel.totalExpenses, color: .red, icon: "arrow.up.circle.fill")
        }
    }

    // health score with rings
    private var healthRings: some View {
        let isCompact = verticalSizeClass == .compact
        let outerSize: CGFloat = isCompact ? 90 : 140
        let middleSize: CGFloat = isCompact ? 74 : 116
        let innerSize: CGFloat = isCompact ? 58 : 92
        let lineWidth: CGFloat = isCompact ? 8 : 12

        return VStack(spacing: 14) {
            Text("Financial Health")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: isCompact ? 16 : 28) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: lineWidth)
                        .frame(width: outerSize, height: outerSize)
                    Circle()
                        .trim(from: 0, to: viewModel.savingsProgress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: outerSize, height: outerSize)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: lineWidth)
                        .frame(width: middleSize, height: middleSize)
                    Circle()
                        .trim(from: 0, to: viewModel.budgetProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: middleSize, height: middleSize)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: lineWidth)
                        .frame(width: innerSize, height: innerSize)
                    Circle()
                        .trim(from: 0, to: viewModel.loggingProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: innerSize, height: innerSize)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(viewModel.healthScore)")
                            .font(isCompact ? .title3.bold() : .title.bold())
                        Text("/ 100")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ringLabel("Savings", pct: viewModel.savingsProgress, color: .green)
                    ringLabel("Budget", pct: viewModel.budgetProgress, color: .orange)
                    ringLabel("Logging", pct: viewModel.loggingProgress, color: .blue)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    private func ringLabel(_ text: String, pct: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption)
            Spacer()
            Text("\(Int(pct * 100))%")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var budgetWarnings: some View {
        if !viewModel.overBudgetCategories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Budget Warnings", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                ForEach(viewModel.overBudgetCategories, id: \.0.id) { (cat, spent, limit) in
                    let pct = limit > 0 ? spent / limit : 0
                    HStack {
                        Image(systemName: cat.iconName).foregroundStyle(cat.color).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name).font(.subheadline.weight(.medium))
                            ProgressView(value: min(pct, 1.0)).tint(pct >= 1.0 ? .red : .orange)
                        }
                        Spacer()
                        Text("\(Int(pct * 100))%").font(.caption.bold())
                            .foregroundStyle(pct >= 1.0 ? .red : .orange)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 6)
        }
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions").font(.headline)
            if viewModel.recentTransactions.isEmpty {
                ContentUnavailableView("No Transactions", systemImage: "tray",
                    description: Text("Tap + to add your first transaction."))
                    .frame(height: 120)
            } else {
                ForEach(viewModel.recentTransactions) { tx in
                    TransactionRowView(
                        transaction: tx,
                        categoryName: viewModel.categoryName(for: tx.categoryID),
                        categoryColor: viewModel.categoryColor(for: tx.categoryID),
                        categoryIcon: viewModel.categoryIcon(for: tx.categoryID)
                    )
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }
}

// shared UI components

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(amount, format: .currency(code: settings.selectedCurrencyCode)).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let categoryName: String
    let categoryColor: Color
    let categoryIcon: String
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(categoryColor.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: categoryIcon).foregroundStyle(categoryColor).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(transaction.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    if transaction.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                Text(categoryName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((transaction.type == .income ? "+" : "-") + transaction.amount.formatted(.currency(code: settings.selectedCurrencyCode)))
                    .font(.subheadline.bold())
                    .foregroundStyle(transaction.type == .income ? .green : .red)
                Text(transaction.date, style: .date).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
