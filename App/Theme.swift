//
//  Theme.swift
//  Spendly
//
//  Created by Sumangala Rao on 28/4/2026.
//
import SwiftUI

enum AppTheme {
    static let navBar  = Color(hex: "#1A3560")
    static let emerald = Color(hex: "#10B981")
    static let mint    = Color(hex: "#34D399")

    // light background
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#D6E8F5"), Color(hex: "#C5EDD8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var lockGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#0D2B55"), Color(hex: "#059669")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// background with leaf decorations
struct AppBackground: View {
    var body: some View {
        AppTheme.gradient
            .overlay(alignment: .topTrailing) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(AppTheme.emerald.opacity(0.15))
                    .rotationEffect(.degrees(-30))
                    .offset(x: -20, y: 60)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 55))
                    .foregroundStyle(AppTheme.emerald.opacity(0.12))
                    .rotationEffect(.degrees(25))
                    .offset(x: -70, y: 120)
            }
            .overlay(alignment: .bottomLeading) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(AppTheme.emerald.opacity(0.12))
                    .rotationEffect(.degrees(150))
                    .offset(x: 20, y: -80)
            }
            .overlay(alignment: .bottomLeading) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(AppTheme.emerald.opacity(0.10))
                    .rotationEffect(.degrees(60))
                    .offset(x: 160, y: -300)
            }
            .ignoresSafeArea()
    }
}
