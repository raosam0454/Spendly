import SwiftUI
import SwiftData

@MainActor
final class TransactionFormViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var amountText: String = ""
    @Published var type: TransactionType = .expense
    @Published var selectedCategoryID: UUID? = nil
    @Published var date: Date = Date()
    @Published var notes: String = ""
    @Published var recurrence: RecurrenceRule = .none
    @Published var categories: [Category] = []

    @Published var titleError: String? = nil
    @Published var amountError: String? = nil
    @Published var categoryError: String? = nil
    @Published var saveError: String? = nil

    private let dataService: DataService
    var existingTransaction: Transaction?

    init(dataService: DataService, transaction: Transaction? = nil) {
        self.dataService = dataService
        self.existingTransaction = transaction
        if let tx = transaction {
            title = tx.title
            amountText = String(format: "%.2f", tx.amount)
            type = tx.type
            selectedCategoryID = tx.categoryID
            date = tx.date
            notes = tx.notes ?? ""
            recurrence = tx.recurrence
        }
    }

    func load() {
        categories = dataService.fetchCategories()
        if selectedCategoryID == nil { selectedCategoryID = categories.first?.id }
    }

    @discardableResult func validateTitle() -> Bool {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            titleError = "Title cannot be empty."
            return false
        }
        titleError = nil
        return true
    }

    @discardableResult func validateAmount() -> Bool {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { amountError = "Amount cannot be empty."; return false }
        guard let val = Double(trimmed) else { amountError = "Please enter a valid number."; return false }
        if val <= 0 { amountError = "Amount must be greater than zero."; return false }
        amountError = nil
        return true
    }

    @discardableResult func validateCategory() -> Bool {
        guard let id = selectedCategoryID else {
            categoryError = "Please select a category."
            return false
        }
        // confirm the selected category still exists (user may have deleted it)
        guard categories.contains(where: { $0.id == id }) else {
            categoryError = "The selected category no longer exists. Please choose another."
            selectedCategoryID = categories.first?.id
            return false
        }
        categoryError = nil
        return true
    }

    func save() throws {
        guard validateTitle(), validateAmount(), validateCategory() else { return }
        guard let amount = Double(amountText), let catID = selectedCategoryID else { return }
        let tx = Transaction(
            id: existingTransaction?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            type: type,
            categoryID: catID,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            recurrence: recurrence
        )
        if existingTransaction != nil {
            try dataService.updateTransaction(tx)
        } else {
            try dataService.addTransaction(tx)
        }
    }
}

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    var transaction: Transaction? = nil
    var onSave: (() -> Void)? = nil

    @StateObject private var viewModel: TransactionFormViewModel

    init(modelContext: ModelContext, transaction: Transaction? = nil, onSave: (() -> Void)? = nil) {
        self.modelContext = modelContext
        self.transaction = transaction
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: TransactionFormViewModel(
            dataService: DataService(modelContext: modelContext),
            transaction: transaction
        ))
    }

    var body: some View {
        NavigationStack {
            // ScrollView replaces Form — Form's underlying UICollectionView doesn't reliably
            // scroll to a TextEditor cell when the keyboard appears in a sheet.
            // With a plain ScrollView we get full, predictable keyboard avoidance.
            ScrollView {
                VStack(spacing: 16) {
                    // type picker
                    formCard {
                        Picker("Type", selection: $viewModel.type) {
                            ForEach(TransactionType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                    }

                    // title
                    formCard(header: "Title") {
                        TextField("e.g. Coffee, Salary", text: $viewModel.title)
                            .onChange(of: viewModel.title) { _, _ in viewModel.validateTitle() }
                        if let e = viewModel.titleError {
                            Text(e).font(.caption).foregroundStyle(.red)
                        }
                    }

                    // amount
                    formCard(header: "Amount") {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $viewModel.amountText)
                                .keyboardType(.decimalPad)
                                .onChange(of: viewModel.amountText) { _, _ in viewModel.validateAmount() }
                        }
                        if let e = viewModel.amountError {
                            Text(e).font(.caption).foregroundStyle(.red)
                        }
                    }

                    // category
                    formCard(header: "Category") {
                        Picker("Category", selection: $viewModel.selectedCategoryID) {
                            ForEach(viewModel.categories) { cat in
                                Label(cat.name, systemImage: cat.iconName).tag(Optional(cat.id))
                            }
                        }
                        if let e = viewModel.categoryError {
                            Text(e).font(.caption).foregroundStyle(.red)
                        }
                    }

                    // date
                    formCard(header: "Date") {
                        DatePicker("", selection: $viewModel.date,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }

                    // repeat
                    formCard(header: "Repeat") {
                        Picker("Repeat", selection: $viewModel.recurrence) {
                            ForEach(RecurrenceRule.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.menu)
                    }

                    // notes — TextEditor with fixed min height so it's always fully visible
                    formCard(header: "Notes") {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $viewModel.notes)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                            if viewModel.notes.isEmpty {
                                Text("Optional notes...")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    if let e = viewModel.saveError {
                        Text(e).foregroundStyle(.red).font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { handleSave() }.bold() }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear { viewModel.load() }
        }
    }

    // helper that gives each field the same card-style container as a Form section
    @ViewBuilder
    private func formCard<Content: View>(
        header: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func handleSave() {
        do {
            try viewModel.save()
            NotificationCenter.default.post(name: .spendlyTransactionChanged, object: nil)
            onSave?()
            dismiss()
        } catch {
            viewModel.saveError = error.localizedDescription
        }
    }
}
