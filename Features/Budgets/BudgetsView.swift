//
//  BudgetsView.swift
//  Spendly
//
//  Created by Dhairya Shah on 5/5/2026.
//

import SwiftUI
import SwiftData

// wrapper to get modelContext properly instead of the old in-memory hack
struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        BudgetsContent(modelContext: modelContext)
    }
}

struct BudgetsContent: View {
    @StateObject private var viewModel: BudgetsViewModel
    @State private var showBudgetForm = false
    @State private var showTemplateSheet = false
    @State private var editingCategory: Category? = nil
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: BudgetsViewModel(
            dataService: DataService(modelContext: modelContext)
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // maxWidth: .infinity is critical — without it the VStack has no
                // explicit width and LazyVGrid cannot compute its column widths,
                // which breaks height calculation and prevents scrolling
                VStack(spacing: 0) {
                    // show template button if no budgets set yet
                    if !viewModel.hasBudgetsThisMonth {
                        Button {
                            showTemplateSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Use a Budget Template")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.navBar)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.categories) { cat in
                            BudgetCategoryCard(
                                category: cat,
                                budget: viewModel.budget(for: cat.id),
                                spent: viewModel.spentAmount(for: cat.id),
                                progress: viewModel.progressFraction(for: cat.id),
                                progressColor: viewModel.progressColor(for: cat.id)
                            )
                            .onTapGesture {
                                if viewModel.budget(for: cat.id) != nil {
                                    viewModel.selectedCategory = cat
                                } else {
                                    editingCategory = cat
                                    showBudgetForm = true
                                }
                            }
                            .contextMenu {
                                Button { editingCategory = cat; showBudgetForm = true } label: {
                                    Label("Set Budget", systemImage: "pencil")
                                }
                                if viewModel.budget(for: cat.id) != nil {
                                    Button(role: .destructive) {
                                        viewModel.deleteBudget(for: cat.id)
                                    } label: {
                                        Label("Remove Budget", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showBudgetForm = true; editingCategory = nil } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showBudgetForm, onDismiss: { viewModel.load() }) {
                BudgetFormView(viewModel: viewModel, preselectedCategory: editingCategory)
            }
            .sheet(isPresented: $showTemplateSheet, onDismiss: { viewModel.load() }) {
                TemplatePickerView(viewModel: viewModel)
            }
            .sheet(item: Binding(
                get: { viewModel.selectedCategory },
                set: { viewModel.selectedCategory = $0 }
            )) { cat in
                CategoryTransactionsView(category: cat, viewModel: viewModel)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// category card with progress ring
struct BudgetCategoryCard: View {
    let category: Category
    let budget: Budget?
    let spent: Double
    let progress: Double
    let progressColor: Color
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                Image(systemName: category.iconName)
                    .foregroundStyle(category.color)
                    .font(.system(size: 22))
            }
            Text(category.name)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let b = budget {
                VStack(spacing: 2) {
                    Text("\(spent.formatted(.currency(code: settings.selectedCurrencyCode))) / \(b.monthlyLimit.formatted(.currency(code: settings.selectedCurrencyCode)))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold()).foregroundStyle(progressColor)
                }
            } else {
                Text("No budget")
                    .font(.caption2).foregroundStyle(.secondary).italic()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 6)
    }
}

// set or edit budget for a category
struct BudgetFormView: View {
    @ObservedObject var viewModel: BudgetsViewModel
    @Environment(\.dismiss) private var dismiss
    var preselectedCategory: Category?

    @State private var selectedCategoryID: UUID? = nil
    @State private var limitText: String = ""
    @State private var limitError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(viewModel.categories) { cat in
                            Label(cat.name, systemImage: cat.iconName).tag(Optional(cat.id))
                        }
                    }
                }
                Section("Monthly Limit") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $limitText).keyboardType(.decimalPad)
                        }
                        if let err = limitError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { handleSave() }.bold() }
            }
            .onAppear {
                selectedCategoryID = preselectedCategory?.id ?? viewModel.categories.first?.id
                if let cat = preselectedCategory, let b = viewModel.budget(for: cat.id) {
                    limitText = String(format: "%.2f", b.monthlyLimit)
                }
            }
        }
    }

    private func handleSave() {
        guard let catID = selectedCategoryID else { limitError = "Select a category."; return }
        guard let value = Double(limitText), value > 0 else {
            limitError = "Enter a valid amount greater than zero."; return
        }
        limitError = nil
        viewModel.addOrUpdateBudget(categoryID: catID, limit: value)
        dismiss()
    }
}

// transactions for a specific category
struct CategoryTransactionsView: View {
    let category: Category
    @ObservedObject var viewModel: BudgetsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.transactionsFor(category: category)) { tx in
                    TransactionRowView(
                        transaction: tx,
                        categoryName: category.name,
                        categoryColor: category.color,
                        categoryIcon: category.iconName
                    )
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// pick from preset budget templates
struct TemplatePickerView: View {
    @ObservedObject var viewModel: BudgetsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(budgetTemplates) { template in
                    Button {
                        viewModel.applyTemplate(template)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(template.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // show what limits it sets
                            let items = template.limits.sorted { $0.key < $1.key }
                            HStack {
                                ForEach(items.prefix(3), id: \.key) { name, amount in
                                    Text("\(name): $\(Int(amount))")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                if items.count > 3 {
                                    Text("+\(items.count - 3) more")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Budget Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
