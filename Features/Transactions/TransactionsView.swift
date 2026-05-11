import SwiftUI
import SwiftData

// wrapper for modelContext injection
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TransactionsContent(modelContext: modelContext)
    }
}

struct TransactionsContent: View {
    @StateObject private var viewModel: TransactionsViewModel
    @State private var showAddSheet = false
    @State private var editingTransaction: Transaction? = nil
    @State private var showFilterSheet = false
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: TransactionsViewModel(
            dataService: DataService(modelContext: modelContext)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // search bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search transactions...", text: $viewModel.searchText)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal).padding(.vertical, 8)

                    if viewModel.groupedTransactions.isEmpty {
                        ContentUnavailableView("No Transactions", systemImage: "tray",
                            description: Text(viewModel.searchText.isEmpty ? "Add your first transaction." : "No results found."))
                    } else {
                        List {
                            ForEach(viewModel.groupedTransactions, id: \.0) { (date, txs) in
                                Section {
                                    ForEach(txs) { tx in
                                        TransactionRowView(
                                            transaction: tx,
                                            categoryName: viewModel.categoryName(for: tx.categoryID),
                                            categoryColor: viewModel.categoryColor(for: tx.categoryID),
                                            categoryIcon: viewModel.categoryIcon(for: tx.categoryID)
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingTransaction = tx }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                viewModel.confirmDelete(id: tx.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                } header: {
                                    Text(date, style: .date).font(.caption.uppercaseSmallCaps())
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // undo toast
                if viewModel.showUndoToast {
                    UndoToastView {
                        viewModel.undoDelete()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showUndoToast)
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showFilterSheet = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(AppTheme.emerald)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showAddSheet, onDismiss: { viewModel.load() }) {
                TransactionFormView(modelContext: modelContext, onSave: { viewModel.load() })
            }
            .sheet(item: $editingTransaction, onDismiss: { viewModel.load() }) { tx in
                TransactionFormView(modelContext: modelContext, transaction: tx, onSave: { viewModel.load() })
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { viewModel.executeDelete() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
        }
    }
}

// small toast that shows after deleting with an undo button
struct UndoToastView: View {
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "trash").foregroundStyle(.white.opacity(0.7))
            Text("Transaction deleted").foregroundStyle(.white).font(.subheadline)
            Spacer()
            Button("Undo") {
                onUndo()
            }
            .font(.subheadline.bold())
            .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct FilterSheetView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $viewModel.selectedTypeFilter) {
                        Text("All").tag(Optional<TransactionType>.none)
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(Optional(t))
                        }
                    }.pickerStyle(.segmented)
                }
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategoryFilter) {
                        Text("All").tag(Optional<UUID>.none)
                        ForEach(viewModel.categories) { cat in
                            Label(cat.name, systemImage: cat.iconName).tag(Optional(cat.id))
                        }
                    }
                }
                // toggles prevent the picker from silently snapping to "today"
                // when the user hasn't intentionally set a date range
                Section("Date Range") {
                    Toggle("Filter from date", isOn: Binding(
                        get: { viewModel.dateRangeStart != nil },
                        set: { viewModel.dateRangeStart = $0 ? Calendar.current.startOfDay(for: Date()) : nil }
                    ))
                    if viewModel.dateRangeStart != nil {
                        DatePicker("From", selection: Binding(
                            get: { viewModel.dateRangeStart ?? Date() },
                            set: { viewModel.dateRangeStart = $0 }
                        ), displayedComponents: .date)
                    }
                    Toggle("Filter to date", isOn: Binding(
                        get: { viewModel.dateRangeEnd != nil },
                        set: { viewModel.dateRangeEnd = $0 ? Date() : nil }
                    ))
                    if viewModel.dateRangeEnd != nil {
                        DatePicker("To", selection: Binding(
                            get: { viewModel.dateRangeEnd ?? Date() },
                            set: { viewModel.dateRangeEnd = $0 }
                        ), displayedComponents: .date)
                    }
                }
                Section { Button("Clear Filters", role: .destructive) { viewModel.clearFilters() } }
            }
            .navigationTitle("Filters")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
