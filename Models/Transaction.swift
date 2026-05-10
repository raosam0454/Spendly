//
//  Transaction.swift
//  Spendly
//
//  Created by Sumangala Rao on 28/4/2026.
//
import Foundation
import SwiftData

// transaction types - just add a new case here if we need more later
enum TransactionType: String, Codable, CaseIterable {
    case income = "Income"
    case expense = "Expense"
}

// for recuring transactions like rent, salary etc
enum RecurrenceRule: String, Codable, CaseIterable {
    case none = "None"
    case weekly = "Weekly"
    case fortnightly = "Fortnightly"
    case monthly = "Monthly"
}

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let amount: Double
    let type: TransactionType
    let categoryID: UUID
    let date: Date
    let notes: String?
    let recurrence: RecurrenceRule

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        type: TransactionType,
        categoryID: UUID,
        date: Date = Date(),
        notes: String? = nil,
        recurrence: RecurrenceRule = .none
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.categoryID = categoryID
        self.date = date
        self.notes = notes
        self.recurrence = recurrence
    }

    var isRecurring: Bool { recurrence != .none }
}

// swiftdata model for persistence
@Model
final class TransactionModel {
    var id: UUID
    var title: String
    var amount: Double
    var typeRaw: String
    var categoryID: UUID
    var date: Date
    var notes: String?
    var recurrenceRaw: String = "None"

    init(from transaction: Transaction) {
        self.id = transaction.id
        self.title = transaction.title
        self.amount = transaction.amount
        self.typeRaw = transaction.type.rawValue
        self.categoryID = transaction.categoryID
        self.date = transaction.date
        self.notes = transaction.notes
        self.recurrenceRaw = transaction.recurrence.rawValue
    }

    var asStruct: Transaction {
        Transaction(
            id: id,
            title: title,
            amount: amount,
            type: TransactionType(rawValue: typeRaw) ?? .expense,
            categoryID: categoryID,
            date: date,
            notes: notes,
            recurrence: RecurrenceRule(rawValue: recurrenceRaw) ?? .none
        )
    }
}
