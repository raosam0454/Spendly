# Spendly (SpendWise)

Budget & Expense Tracker for university students.

## Features
- Track income and expenses with categories
- Set monthly budgets per category with progress rings
- Financial health score (savings, budget adherence, logging consistency)
- Recurring transactions (weekly, fortnightly, monthly)
- Budget templates for quick setup
- Undo deleted transactions
- Analytics with bar, line, and donut charts
- Face ID / Passcode lock
- Push notifications for budget warnings and daily reminders
- Live currency conversion via ExchangeRate-API
- Data-driven categories (add new ones without code changes)

## Tech Stack
- SwiftUI + SwiftData (iOS 17+)
- Swift Charts
- LocalAuthentication
- UserNotifications
- URLSession + async/await

## Architecture
- MVVM with immutable data structs
- Functional separation: DataService, NotificationService, CurrencyService
- Loose coupling via ViewModelFactory
- All models use immutable `let` properties

## Setup
1. Open `Spendly.xcodeproj` in Xcode
2. Add your ExchangeRate-API key to `Config.plist`
3. Build and run on iOS 17+ simulator or device

## Team
- Sam - Initial app architecture and models , Bug fixes Feature: The main dashboard
- Kunj - 
- Dhairya - 
- Jenil - 

## GitHub
https://github.com/raosam0454/Spendly
