//
//  Category.swift
//  Spendly
//
//  Created by Sumangala Rao on 29/4/2026.
//
import Foundation
import SwiftUI
import SwiftData

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }

    var color: Color { Color(hex: colorHex) }
}

// default categories - add more here without touching any other code
extension Category {
    static let defaults: [Category] = [
        Category(name: "Food & Dining",    iconName: "fork.knife",            colorHex: "#FF6B6B"),
        Category(name: "Transport",        iconName: "car.fill",              colorHex: "#4ECDC4"),
        Category(name: "Shopping",         iconName: "bag.fill",              colorHex: "#45B7D1"),
        Category(name: "Entertainment",    iconName: "tv.fill",               colorHex: "#96CEB4"),
        Category(name: "Health",           iconName: "heart.fill",            colorHex: "#FFEAA7"),
        Category(name: "Education",        iconName: "book.fill",             colorHex: "#DDA0DD"),
        Category(name: "Bills & Utilities",iconName: "bolt.fill",             colorHex: "#98D8C8"),
        Category(name: "Rent",             iconName: "house.fill",            colorHex: "#F7DC6F"),
        Category(name: "Salary / Income",  iconName: "dollarsign.circle.fill",colorHex: "#82E0AA"),
        Category(name: "Other",            iconName: "ellipsis.circle.fill",  colorHex: "#AEB6BF")
    ]
}

@Model
final class CategoryModel {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var sortOrder: Int

    init(from category: Category, sortOrder: Int = 0) {
        self.id = category.id
        self.name = category.name
        self.iconName = category.iconName
        self.colorHex = category.colorHex
        self.sortOrder = sortOrder
    }

    var asStruct: Category {
        Category(id: id, name: name, iconName: iconName, colorHex: colorHex)
    }
}

// hex string to Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
