//
//  SettingsView.swift
//  Spendly
//
//  Created by Sumangala Rao on 6/5/2026.
//
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    HStack {
                        Label("Face ID / Passcode", systemImage: "faceid")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isFaceIDEnabled },
                            set: { _ in Task { await viewModel.toggleFaceID() } }
                        ))
                    }
                }

                Section("Notifications") {
                    Toggle(isOn: $viewModel.isDailyReminderEnabled) {
                        Label("Daily Spending Reminder", systemImage: "bell.fill")
                    }
                    if viewModel.isDailyReminderEnabled {
                        Picker("Reminder Hour", selection: $viewModel.reminderHour) {
                            ForEach(6..<24, id: \.self) { h in
                                Text(String(format: "%02d:00", h)).tag(h)
                            }
                        }
                    }
                    Toggle(isOn: $viewModel.isBudgetAlertsEnabled) {
                        Label("Budget Alerts (80% & 100%)", systemImage: "exclamationmark.triangle.fill")
                    }
                }

                Section("Currency") {
                    if viewModel.isLoadingCurrencies {
                        HStack { ProgressView(); Text("Loading exchange rates...").foregroundStyle(.secondary) }
                    } else if let error = viewModel.currencyLoadError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error).foregroundStyle(.red).font(.caption)
                            Button("Retry") { Task { await viewModel.loadCurrencies() } }.font(.caption)
                        }
                    } else {
                        Picker("Display Currency", selection: $viewModel.selectedCurrencyCode) {
                            ForEach(viewModel.availableCurrencies) { r in Text(r.code).tag(r.code) }
                        }
                    }
                }

                Section("Categories") {
                    NavigationLink("Manage Categories") {
                        CategoryManagerView()
                    }
                }

                Section("Danger Zone") {
                    Button(role: .destructive) { viewModel.showClearConfirmation = true } label: {
                        Label("Clear All Data", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { Task { await viewModel.loadCurrencies() } }
            .alert("Error", isPresented: .init(
                get: { viewModel.notificationError != nil },
                set: { if !$0 { viewModel.notificationError = nil } }
            )) {
                Button("OK") { viewModel.notificationError = nil }
            } message: { Text(viewModel.notificationError ?? "") }
            .confirmationDialog("Clear All Data", isPresented: $viewModel.showClearConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    viewModel.clearAllData(dataService: DataService(modelContext: modelContext))
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all transactions, budgets, and categories.")
            }
        }
    }
}

// manage categories - add, edit, delete, reorder
struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var categories: [Category] = []
    @State private var showAddSheet = false
    @State private var editingCategory: Category? = nil

    var body: some View {
        List {
            ForEach(categories) { cat in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(cat.color.opacity(0.15)).frame(width: 36, height: 36)
                        Image(systemName: cat.iconName).foregroundStyle(cat.color)
                    }
                    Text(cat.name)
                    Spacer()
                    Button { editingCategory = cat } label: {
                        Image(systemName: "pencil").foregroundStyle(.blue)
                    }.buttonStyle(.plain)
                }
            }
            .onDelete(perform: deleteCategories)
            .onMove(perform: moveCategories)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .onAppear { loadCategories() }
        .sheet(isPresented: $showAddSheet, onDismiss: loadCategories) {
            CategoryFormView(onSave: loadCategories)
        }
        .sheet(item: $editingCategory, onDismiss: loadCategories) { cat in
            CategoryFormView(category: cat, onSave: loadCategories)
        }
    }

    private func loadCategories() {
        categories = DataService(modelContext: modelContext).fetchCategories()
    }

    private func deleteCategories(at offsets: IndexSet) {
        let ds = DataService(modelContext: modelContext)
        for i in offsets { try? ds.deleteCategory(id: categories[i].id) }
        loadCategories()
    }

    private func moveCategories(from: IndexSet, to: Int) {
        var copy = categories
        copy.move(fromOffsets: from, toOffset: to)
        try? DataService(modelContext: modelContext).reorderCategories(copy)
        loadCategories()
    }
}

// add or edit a category
struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var category: Category? = nil
    var onSave: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedIcon: String = "circle.fill"
    @State private var colorHex: String = "#4ECDC4"
    @State private var nameError: String? = nil

    let icons = ["fork.knife","car.fill","bag.fill","tv.fill","heart.fill","book.fill",
                 "bolt.fill","house.fill","dollarsign.circle.fill","ellipsis.circle.fill",
                 "airplane","gamecontroller.fill","music.note","camera.fill","leaf.fill"]
    let presets = ["#FF6B6B","#4ECDC4","#45B7D1","#96CEB4","#FFEAA7","#DDA0DD","#82E0AA","#F7DC6F","#AEB6BF","#E59866"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Category name", text: $name)
                        if let err = nameError { Text(err).font(.caption).foregroundStyle(.red) }
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color(hex: colorHex) : Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { selectedIcon = icon }
                        }
                    }.padding(.vertical, 4)
                }
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 10) {
                        ForEach(presets, id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 40, height: 40)
                                .overlay(Circle().stroke(colorHex == hex ? Color.primary : .clear, lineWidth: 3))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { handleSave() }.bold() }
            }
            .onAppear {
                if let cat = category { name = cat.name; selectedIcon = cat.iconName; colorHex = cat.colorHex }
            }
        }
    }

    private func handleSave() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { nameError = "Name cannot be empty."; return }
        nameError = nil
        let ds = DataService(modelContext: modelContext)
        let cat = Category(id: category?.id ?? UUID(), name: name, iconName: selectedIcon, colorHex: colorHex)
        if category != nil { try? ds.updateCategory(cat) }
        else { try? ds.addCategory(cat) }
        onSave?()
        dismiss()
    }
}
