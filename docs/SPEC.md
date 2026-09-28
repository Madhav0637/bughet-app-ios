# Koku (formerly BudgetApp) — Specification

> Status: **2.0 redesign built** (2026-09-26): renamed Koku, new minimalist design with Light/Dark/System themes and
> highlight colours, monthly budget with alerts, Insights tab, faster Add screen. The MVP (1.0) was completed on
> 2026-09-24; its spec was finalized 2026-09-23. The Android app is getting the same 2.0 redesign and features
> (see section 12).

## 1. Overview

A minimal personal expense tracker for iPhone whose core advantage is **speed of capture**. An expense is logged by double-tapping the back of the iPhone, answering three quick prompts, and it saves silently. A dashboard shows where the money went.

**Success metric:** log an expense in **under 5 seconds**, starting from an unlocked phone, without opening the app.

**Audience:** a single user (personal use). Built solo as a learning and portfolio project.

## 2. Decision log

| Area | Decision |
|---|---|
| Name | **Koku** (display name and branding, from 2.0). The bundle ID and the Log Expense intent are unchanged, so existing shortcuts and data carry over |
| Platform | iPhone only, native Swift, minimum iOS 26 |
| Quick entry | Back Tap → Shortcut → "On what?" → amount → category → silent save |
| Prompt style | Keep the iOS pop-up over the current screen. iOS draws the text prompt in its standard style (smaller than the number prompt) and offers no font control; a full-screen in-app entry screen was tried and rejected (2026-09-24) |
| Lock state | Quick entry works only when the iPhone is unlocked (Face ID) |
| Capture | Manual entry only (no SMS, bank, or receipt capture) |
| Data | On-device only. No backend, no login, no sync |
| Currency | INR only, whole rupees (no paise) |
| Required fields | Merchant, amount, and category, always all three. A note is optional (2.0) |
| Category step | Back Tap: always picked from the list. In-app (2.0): a merchant used before fills in the category it was last logged under, until a category is tapped by hand |
| Date | Back Tap: always "now". In-app (2.0): defaults to now, any date can be picked when adding or editing |
| Categories | Presets plus user-managed (add, edit, delete), each with a name and an emoji |
| Category order | Most-used first; ties sorted alphabetically |
| Category deletion | Blocked while any expense uses it; a "Move all expenses to…" action empties a category |
| Home periods | Week, Month, or Year, current period only; the choice is remembered |
| Insights periods (2.0) | Week, Month, or Year, current or any earlier period (arrows or swipe); never the future |
| Comparisons (2.0) | A running period is compared with the same stretch of the previous one (1–26 Sep vs 1–26 Aug); a finished one with the whole previous period |
| Period boundaries | Weeks start Monday, months start on the 1st |
| Charts (2.0) | Swift Charts. Neutral bars with one highlighted bar (the tapped one, else the peak) and a dashed average line |
| Budget (2.0) | One monthly budget in whole rupees, stored in UserDefaults. Alerts at 80% and 100%, each at most once a month, shared by the app (banner) and Back Tap (notification) |
| Design (2.0) | Neutral canvas, one highlight colour (mint by default; lime, sky, periwinkle, coral or amber), SF Pro Rounded, Liquid Glass tab bar. Light / Dark / System, applied to the whole window |
| History | Full list with search (merchant) and category filter across all dates; edit and delete |
| App lock | None |
| Signing | Free Apple ID (app must be reinstalled from Xcode every 7 days) |

## 3. Scope

### In the MVP
- Quick entry through the Back Tap Shortcut
- In-app "Add expense" (same three fields)
- Dashboard: period switcher, total, category breakdown, 5 most recent expenses
- History: search, category filter, edit, swipe to delete
- Category management: add, edit, delete (blocked while in use), move all expenses to another category
- Export as a CSV spreadsheet or a PDF report, shared as a real file
- Back Tap setup guide in Settings
- Dark mode (follows the system setting)

### Added in 2.0
- Redesign and rename to Koku; in-app Light / Dark / System and six highlight colours
- Home: hero total with comparison, monthly budget card, last 7 days chart, top categories, recent expenses
- Monthly budget with safe-to-spend per day, and 80% / 100% alerts (banner in the app, notification from Back Tap)
- Insights tab: period browsing, bar chart, category breakdown, biggest spend, most visited, average per day, no-spend days, top merchants
- Add/Edit: custom keypad, merchant suggestions with automatic category, optional note, date picker, delete from the edit screen
- Activity: category chips, day totals, undo after delete
- Notes in the CSV export

### Added after 2.0: widgets
- **Today widget:** Lock Screen circular (1 tile: today's total; with a budget, a ring for today's safe-to-spend amount judged at the start of the day), rectangular (2 tiles: today, budget left and per day, last 7 days) and inline; Home Screen small and medium (glassy background with the highlight colour, + button, last expense, 7-day bars). Tapping opens Home (1 tile, small) or Insights (2 tiles, medium).
- **Log Expense control** (Lock Screen, Control Center, Action button): opens Add Expense through `OpenKokuIntent`.
- **Data flow:** the app writes a small `WidgetSnapshot` JSON into the App Group `group.com.madhav0637.budgetapp` after every database save (so Back Tap entries update it too) and when the budget or highlight changes. The widget never opens the database; day and month rollovers are worked out when it draws, with timeline entries at the next midnights. `koku://home|activity|insights|add` links open screens.
- iOS can't expand a Lock Screen widget in place, so the 2-tile size is the "expanded" version.

### Still out of scope
Income, per-category budgets, recurring expenses, app lock, logging streaks, reminders, cloud sync or backup, multiple currencies, paise, receipts, automatic capture.

## 4. Tech stack

| Layer | Choice |
|---|---|
| Language / UI | Swift, SwiftUI, Swift Charts |
| Persistence | SwiftData (on-device) |
| Quick entry | App Intents |
| Tests | Swift Testing (unit), XCTest UI tests |
| Tooling | Xcode 27; built and run on an iPhone 13 (iOS 26) and the simulator |
| Dependencies | None |

## 5. Architecture

```
Back Tap → Shortcut → LogExpenseIntent ──┐
                                         ├──→ Services ──→ SwiftData store
SwiftUI screens (Add/Edit, Categories) ──┘       ↑
                                                 │ read-only
SwiftUI screens (Home, Activity, Insights) ─ queries
```

- **Reads:** screens read through SwiftData queries, which refresh automatically when data changes.
- **Writes:** every change goes through a service, so the Shortcut and the app apply the same validation.
- **Calculations** (period ranges, totals, filtering, CSV and PDF) are plain functions with no UI or database code, so they can be unit-tested on their own.
- **No per-screen view models.** SwiftData queries are designed to live in views, and a view-model layer would add code without adding value at this size.
- **The intent lives in the main app target** (no separate extension). It shares the app's database and needs no paid-account capabilities.
- **Expected volume:** about 10 entries a day, roughly 3,650 a year. Aggregating a year of data in memory is fine at this scale.

## 6. Data model

### Category

| Field | Type | Rules |
|---|---|---|
| id | UUID | |
| name | String | Required; trimmed; unique regardless of case |
| emoji | String | Required; one emoji |
| expenses | [Expense] | Inverse relationship; deletion blocked while not empty |

### Expense

| Field | Type | Rules |
|---|---|---|
| id | UUID | |
| merchant | String | Required; trimmed; not empty |
| amount | Int | Whole rupees; greater than 0 |
| date | Date | Set to now on creation; editable in the app; indexed |
| category | Category | Required |
| note | String? | Optional (2.0); trimmed, blank stored as nil. Optional so 1.0 stores open without a migration step |

### Rules
- **Default categories**, created on first launch: 🍔 Food, 🚕 Transport, 🛍️ Shopping, 🧾 Bills, 🎬 Entertainment, 💊 Health, 📦 Other.
- **At least one category must always exist,** otherwise quick entry has nothing to offer.
- **Category order everywhere** (Shortcut list, in-app picker, Settings): number of expenses, highest first, then alphabetical. New categories start at the bottom.

## 7. Interfaces

There is no server, so there is no REST API. The app exposes one system-facing action and a set of internal services.

### LogExpenseIntent (system-facing)

| Property | Value |
|---|---|
| Title | Log Expense |
| Parameters, in order | `merchant` (text, prompt "On what?") → `amount` (whole number, prompt "Amount (₹)") → `category` (chosen from the category list, most-used first) |
| Opens the app | No |
| Authentication | Requires an unlocked device |
| Success result | None (silent) |
| Failure result | Error message, e.g. "Amount must be more than ₹0" |

### Internal services

| Service | Responsibilities |
|---|---|
| ExpenseService | Add, update, and delete expenses; validate merchant, amount, and category |
| CategoryService | Create defaults on first launch; add and edit categories; move all expenses from one category to another; delete (fails with "Used by N expenses" when not empty, or when it is the last category); return categories in usage order |
| PeriodCalculator | Return the date range of the current week (Monday start), month (1st), or year, in the device time zone |
| SpendingSummary | For a period: total, per-category amounts (highest first), and the 5 most recent expenses |
| CSVExporter | Export all expenses as CSV with columns `Date` (`yyyy-MM-dd HH:mm`), `Merchant`, `Category`, `Amount` (plain integer). Escapes commas, quotes and line breaks; prefixes text starting with = + - @ with an apostrophe |
| PDFReport | A4 report: title, date range, total, spending by category with percentages, and a paginated table of every expense |
| ExportWriter | Writes a CSV or PDF to a dated file (`BudgetApp-expenses-yyyy-MM-dd.csv` / `.pdf`) so the share sheet keeps the extension |
| HistoryFilter | Merchant search (ignores case and accents), category filter, grouping by day, day titles and totals |
| PeriodInsights (2.0) | For one period: total, chart buckets (days, or months for a year), category totals, biggest expense, top and most frequent merchants, days so far, no-spend days, averages; also the last 7 days for Home |
| PeriodComparison (2.0) | Current vs previous period, using the same stretch of the previous period while the current one is running |
| BudgetPace (2.0) | Remaining, progress, days left (counting today) and safe-to-spend per day |
| BudgetAlerts / BudgetService (2.0) | Whether a save crossed 80% or 100% of the monthly budget for the first time this month; the alert text |
| BudgetNotifier (2.0) | Notification permission and posting the alert as a notification (Back Tap) |
| MerchantSuggestions (2.0) | Unique merchants, most recent first; matching typed text; the category a merchant was last logged under |
| KeypadInput (2.0) | Keypad rules: no leading zeros, "00", delete, at most 9 digits |

### Formatting
Amounts are shown as `₹` with Indian digit grouping and no decimals, e.g. `₹1,23,456`.

## 8. Screens and flows

### Quick entry
1. Double-tap the back of the iPhone (phone unlocked)
2. "On what?" → type the merchant → Done
3. "Amount (₹)" → type the amount on the number pad → Done
4. Category list → tap one → saved silently

### Tab 1: Home
- Koku logo and a period menu (This week / This month / This year), remembered
- Hero total for the period, and "↓ 12% vs same time last month" when there was earlier spending
- Budget card for the current month: progress, what's left (or how much over), safe-to-spend per day; tapping it edits the budget. Without a budget: "Set a monthly budget"
- Last 7 days: seven bars, today's in the highlight colour with its amount, and the daily average
- Where it went: the top 3 categories with share bars, "Insights ›"
- Recent: the 5 latest expenses, "See all ›" opens Activity; tap one to edit
- Empty state: "Nothing spent this month"
- A floating **+** button opens Add Expense; toasts (Undo, budget alerts) appear beside it

### Tab 2: Activity
- Search by merchant (case- and accent-insensitive, all dates)
- Category chips ("All" plus every category, most used first); combine with search
- List grouped by day, newest first, with each day's total
- Swipe to delete, then Undo in a toast; tap to open Edit Expense
- A floating **+** button opens Add Expense

### Tab 3: Insights
- Week / Month / Year picker; arrows (or a swipe on the total) move to earlier periods and back, never past now
- Total, comparison pill, number of expenses and average per day
- Bar chart by day (by month for a year); tap a bar for its total, otherwise the peak is highlighted; dashed average line
- Categories: one split bar (biggest in the highlight colour) and each category's amount, count and share
- Tiles: biggest spend, most visited merchant, average per day, no-spend days
- Top 5 merchants by amount

### Tab 4: Settings
- **Appearance:** Theme (System / Light / Dark) and Highlight (six colours)
- **Budget:** monthly budget (keypad sheet with presets and last month's total as a guide, or remove it) and budget alerts (on by default; asks for notification permission; notes when notifications are off in iOS Settings)
- **Categories:** list in usage order, showing each category's expense count. Tap a category to edit its name and emoji, or use "Move all expenses to…". Delete is blocked while the category is in use and points to the move action.
- **Export:** Spreadsheet (CSV) or Report (PDF); the file opens in the share sheet
- **Set up Back Tap:** step-by-step guide:
  1. In the Shortcuts app, create a shortcut containing the "Log Expense" action
  2. Go to Settings → Accessibility → Touch → Back Tap → Double Tap and pick that shortcut

### Add / Edit Expense
- Amount first on a custom keypad (1–9, 00, 0, delete; hold delete to clear), with a blinking caret and "₹X left this month after this" when there's a budget
- "On what?" with suggestions from merchants used before; choosing one fills in its last category ("picked from Zomato")
- Category chips, optional note, and a date pill (Today / Yesterday / a date) that opens a calendar
- The save button says what's missing ("Enter an amount", "Add what it was for", "Pick a category") until it reads "Save ₹420"; saving shows a checkmark and a success haptic
- **Edit:** the same screen, pre-filled, with a delete button (and Undo afterwards)

## 9. Project structure

```
budget-app/
├── BudgetApp.xcodeproj
├── BudgetApp/
│   ├── App/           # App entry point, tabs, ModelContainer setup, demo data (debug)
│   ├── DesignSystem/  # Colours, themes, highlight, shared components, keypad, toasts
│   ├── Models/        # Expense, Category
│   ├── Services/      # ExpenseService, CategoryService, PeriodCalculator, SpendingSummary,
│   │                  # PeriodInsights, Budget, BudgetNotifier, MerchantSuggestions,
│   │                  # HistoryFilter, CSVExporter, PDFReport, ExportWriter
│   ├── Intents/       # LogExpenseIntent, CategoryEntity + query
│   ├── Features/
│   │   ├── Home/
│   │   ├── Activity/
│   │   ├── Insights/
│   │   ├── ExpenseForm/
│   │   └── Settings/  # Budget, Categories, Export, Back Tap guide
│   └── Shared/        # INR and date formatting, the expense row
├── BudgetAppTests/    # Service and calculation tests
├── BudgetAppUITests/  # End-to-end flows on sample data
├── docs/              # SPEC.md, screenshots
└── tools/             # make-app-icon.swift
```

## 10. Build plan

| # | Milestone | Done when | Status |
|---|---|---|---|
| 0 | Setup | Xcode project created; a blank app runs on the iPhone with free signing | ✅ |
| 1 | **Back Tap prototype** | Back Tap logs an expense on the iPhone without opening the app, and it appears in a plain list (see §11) | ✅ |
| 2 | Data layer and tests | Models, services, validation, default categories, PeriodCalculator, SpendingSummary, all unit-tested | ✅ |
| 3 | In-app entry and History | Add/Edit screens, search, category filter, delete | ✅ |
| 4 | Dashboard | Period switcher, total, category breakdown, recent list | ✅ |
| 5 | Category management | Add, edit, move-all, delete rules; the intent's category list reflects changes and usage order | ✅ |
| 6 | Export and polish | CSV and PDF export, empty states, Back Tap guide, dark mode check, app icon | ✅ |
| 7 | Showcase | README with architecture diagram, screenshots, Back Tap demo GIF | ✅ (demo GIF to add once recorded on the iPhone) |
| 8 | 2.0 redesign | Koku design and themes, budget and alerts, Insights, faster Add screen, UI tests, a 1.0 store opens with its data intact | ✅ 2026-09-26 |

## 11. Risks to verify in Milestone 1

All verified on the iPhone on 2026-09-24:

- ✅ The intent asks for its parameters in declaration order (merchant → amount → category)
- ✅ The amount prompt shows a number pad
- ✅ The intent runs without opening the app
- ✅ Back Tap can select the shortcut that contains "Log Expense"
- ✅ Total time from Back Tap to saved is about 5 seconds

Still to confirm over time:
- Free provisioning: after the 7-day expiry, re-running from Xcode keeps existing data (**never delete the app from the phone**)

## 12. Android version

The Android app has the same features and rules, including the Koku 2.0 redesign (built on its `koku-redesign`
branch), and lives in its own repo:
[budget-app-android](https://github.com/Madhav0637/budget-app-android). Its
[spec](https://github.com/Madhav0637/budget-app-android/blob/main/docs/SPEC.md) covers the Android-specific
decisions: the Quick Settings tile, launcher shortcut and brand gestures, and the app's own pop-up.
