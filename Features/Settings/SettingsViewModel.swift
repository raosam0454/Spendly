//
//  SettingsViewModel.swift
//  Spendly
//
//  Created by Sumangala Rao on 6/5/2026.
//
import Foundation
import LocalAuthentication
import SwiftUI

enum AuthResult {
    case success
    case failure(String)
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isFaceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(isFaceIDEnabled, forKey: Keys.faceIDEnabled) }
    }
    @Published var isDailyReminderEnabled: Bool {
        didSet { handleDailyReminderToggle() }
    }
    @Published var isBudgetAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(isBudgetAlertsEnabled, forKey: Keys.budgetAlertsEnabled) }
    }
    @Published var selectedCurrencyCode: String {
        didSet { UserDefaults.standard.set(selectedCurrencyCode, forKey: Keys.selectedCurrency) }
    }
    @Published var availableCurrencies: [CurrencyRate] = []
    @Published var currencyLoadError: String? = nil
    @Published var isLoadingCurrencies = false
    @Published var showClearConfirmation = false
    @Published var clearError: String? = nil
    @Published var notificationError: String? = nil
    @Published var reminderHour: Int = 20 {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Keys.reminderHour)
            guard isDailyReminderEnabled else { return }
            Task {
                let granted = await notificationService.requestPermission()
                if granted {
                    try? await notificationService.scheduleDailyReminder(hour: reminderHour)
                }
            }
        }
    }

    private let notificationService: NotificationService
    private let currencyService: CurrencyService

    init(
        notificationService: NotificationService = .shared,
        currencyService: CurrencyService = .shared
    ) {
        self.notificationService = notificationService
        self.currencyService = currencyService
        self.isFaceIDEnabled = UserDefaults.standard.bool(forKey: Keys.faceIDEnabled)
        self.isDailyReminderEnabled = UserDefaults.standard.bool(forKey: Keys.dailyReminderEnabled)
        self.isBudgetAlertsEnabled = UserDefaults.standard.bool(forKey: Keys.budgetAlertsEnabled)
        self.selectedCurrencyCode = UserDefaults.standard.string(forKey: Keys.selectedCurrency) ?? "AUD"
        self.reminderHour = UserDefaults.standard.integer(forKey: Keys.reminderHour).nonZeroOrDefault(20)
    }

    // face id / passcode

    func authenticate() async -> AuthResult {
        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &error) else {
            return .failure(error?.localizedDescription ?? "Authentication not available on this device.")
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: "Unlock Spendly")
            return success ? .success : .failure("Authentication failed.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func toggleFaceID() async {
        if !isFaceIDEnabled {
            let result = await authenticate()
            switch result {
            case .success: isFaceIDEnabled = true
            case .failure(let msg): notificationError = msg
            }
        } else {
            isFaceIDEnabled = false
        }
    }

    // notifications

    private func handleDailyReminderToggle() {
        UserDefaults.standard.set(isDailyReminderEnabled, forKey: Keys.dailyReminderEnabled)
        Task {
            if isDailyReminderEnabled {
                let granted = await notificationService.requestPermission()
                if granted {
                    try? await notificationService.scheduleDailyReminder(hour: reminderHour)
                } else {
                    await MainActor.run {
                        notificationError = "Notification permission denied. Enable in Settings."
                    }
                }
            } else {
                notificationService.cancelDailyReminder()
            }
        }
    }

    // currency

    func loadCurrencies() async {
        isLoadingCurrencies = true
        currencyLoadError = nil
        do {
            availableCurrencies = try await currencyService.fetchRates()
        } catch {
            currencyLoadError = error.localizedDescription
        }
        isLoadingCurrencies = false
    }

    // clear data

    func clearAllData(dataService: DataService) {
        do {
            try dataService.clearAllData()
            NotificationCenter.default.post(name: .spendlyDataCleared, object: nil)
        } catch {
            clearError = error.localizedDescription
        }
    }
}

private extension Int {
    func nonZeroOrDefault(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}

private enum Keys {
    static let faceIDEnabled        = "faceIDEnabled"
    static let dailyReminderEnabled = "dailyReminderEnabled"
    static let budgetAlertsEnabled  = "budgetAlertsEnabled"
    static let selectedCurrency     = "selectedCurrency"
    static let reminderHour         = "reminderHour"
}

extension Notification.Name {
    static let spendlyDataCleared        = Notification.Name("spendlyDataCleared")
    static let spendlyTransactionChanged = Notification.Name("spendlyTransactionChanged")
}
