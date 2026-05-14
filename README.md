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
- Sam - Enhanced initial app architecture and models , Bug fixes Feature: The main dashboard
- Kunj - Intial full architecture of our application and Analytics page spending charts, category breakdown & trend analysis. UI improvements and bug fixes.
- Dhairya - I built a budgeting screen that lets people easily set and track their spending using simple cards, ready‑made budget setups, and warnings when they’re close to or over their limit along with bug fixes.
- Jenil - Contributed in the app design, Handled Transaction feature and bug fixes

## GitHub
https://github.com/raosam0454/Spendly
