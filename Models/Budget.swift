//
//  Budget.swift
//  Spendly
//
//  Created by Sumangala Rao on 29/4/2026.
//
import Foundation
import SwiftData

struct Budget: Identifiable, Codable, Equatable {
    let id: UUID
    let categoryID: UUID
    let monthlyLimit: Double
    let month: Date

    init(
        id: UUID = UUID(),
        categoryID: UUID,
        monthlyLimit: Double,
        month: Date = Date()
    ) {
        self.id = id
        self.categoryID = categoryID
        self.monthlyLimit = monthlyLimit
        self.month = month
    }
}

@Model
final class BudgetModel {
    var id: UUID
    var categoryID: UUID
    var monthlyLimit: Double
    var month: Date

    init(from budget: Budget) {
        self.id = budget.id
        self.categoryID = budget.categoryID
        self.monthlyLimit = budget.monthlyLimit
        self.month = budget.month
    }

    var asStruct: Budget {
        Budget(id: id, categoryID: categoryID, monthlyLimit: monthlyLimit, month: month)
    }
}
