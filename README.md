# Vero

A simple, fast, and intuitive budgeting app designed to help users understand their spending, identify patterns, and improve their financial life.

---

## 🎯 Vision

The goal of this project is to provide an effortless way to track and understand personal finances, while gradually evolving into a powerful financial insights tool.

The app prioritizes:

- Simplicity and speed
- Clear and meaningful insights
- A pleasant and modern user experience

---

## 🚀 Core Features (MVP)

### 💸 Transactions

- Track income, expenses, and transfers
- Minimal input flow (amount, category, account)
- Optional advanced details:
  - notes
  - tags
  - custom date

Transaction types:
- Income
- Expense
- Transfer (between accounts)

---

### 🔁 Recurring Transactions

- Supports:
  - Daily, weekly, monthly, yearly
  - Custom intervals

Modes:
- Automatic (auto-create transactions)
- Manual (user confirmation required)

Recurring items:
- Act as templates/rules
- Generate normal transactions when due
- Do not affect balances until created
- Can be paused without losing setup

---

### 🗂 Categories

- User-defined categories
- Used for tracking and analytics
- Foundation for future budgeting systems

---

### 🏦 Accounts

Track multiple account types:
- Bank accounts
- Cash
- Savings
- Credit cards

Features:
- Transfers between accounts
- Credit card tracking (including due payments)
- Optional manual/automatic payment tracking

> ⚠️ This is not a banking app. Accounts represent tracked balances, not real integrations.

---

### 💰 Balance System

- Global balance overview (across all accounts)
- Ability to inspect individual accounts
- Future-friendly:
  - Optional focused account view on home screen

---

### 🎯 Goals

- Target amount
- Optional time constraint
- Progress tracking via transactions
- Transactions can be linked to goals

---

### 📈 Investment Simulation (MVP)

- Compound interest calculator
- Adjustable:
  - Initial amount
  - Monthly contributions
  - Interest rate
  - Compounding frequency
  - Inflation adjustment
  - Contribution growth

---

### 📊 Analytics (MVP)

- Spending by category
- Income vs expenses
- Net worth over time

Focus:
- Clarity over complexity
- Fast understanding

---

### 🔐 Authentication

- Google sign-in
- Session persistence
- Independent from local data

---

### 🌍 Multi-Currency

- Default currency (e.g. EUR)
- Per-transaction currency
- Conversion based on date
- Accounts may differ in currency

---

## 🧠 Key Concepts

### 📅 Financial Cycles

The app considers user financial cycles instead of strict calendar months.

Example:
- Salary at end of month
- Rent at beginning of next month

Goal:
Avoid misleading summaries.

---

### ⚡ Speed First UX

- Minimal input
- Fast flows
- Frequent daily usage

---

### 📊 Insight-Oriented Design

The app is not just for tracking—it is for understanding behavior.

Future:
- Spending patterns
- Behavioral insights
- Smart suggestions

---

## 🏗 Architecture (Conceptual)

The app follows a layered architecture:

```
UI (Presentation)
  ↓
ViewModel
  ↓
Repository
  ↓
Data Sources
```

### Layers

#### Presentation
- Screens
- Widgets
- ViewModels

#### Domain
- Entities
- Repository contracts

#### Data
- Repository implementations
- Data sources

---

## 🎨 UI / UX Guidelines

### 🧭 Navigation

- Bottom navigation:
  - Home
  - Transactions
  - Analytics
  - Settings

---

### 🎯 Principles

1. Simplicity first
2. Speed over perfection
3. Progressive disclosure
4. Strong visual hierarchy
5. Consistency

---

### 🎨 Visual Style

Inspired by:
- Apple-like minimalism
- Modern fintech apps

Guidelines:
- Neutral base colors
- Strong accent color
- Clean spacing
- Subtle elevation

---

### 🧩 Components

- Reusable components
- Composition over duplication

---

### ⚡ Interaction

- Fast feedback
- Smooth transitions
- Non-intrusive alerts

---

## 🪵 Logging

- Log only meaningful events
- Avoid noise
- Keep logs concise

---

## 🛣 Roadmap

- Advanced budgeting
- Smart insights
- Bank import
- Shared accounts
- Offline-first sync
- Location-based suggestions

---

## 📌 Notes

This project evolves over time.

Focus:
1. Strong foundation
2. Excellent usability
3. Gradual expansion