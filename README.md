# Vero

A simple, fast, and intuitive budgeting app designed to help users understand their spending, identify patterns, and improve their financial life.

---

## 🎯 Vision

The goal of this project is to provide an **effortless way to track and understand personal finances**, while gradually evolving into a powerful financial insights tool.

The app prioritizes:

* Simplicity and speed
* Clear and meaningful insights
* A pleasant and modern user experience

---

## 🚀 Core Features (MVP)

### 💸 Transactions

* Track income, expenses, and transfers
* Minimal input flow (amount, category, account)
* Optional advanced details:

  * notes
  * tags
  * custom date
* Transaction types:

  * Income
  * Expense
  * Transfer (between accounts)

---

### 🔁 Recurring Transactions

* Supports:

  * Daily, weekly, monthly, yearly
  * Custom intervals
* Modes:

  * Automatic (auto-create transactions)
  * Manual (user confirmation required)

---

### 🗂 Categories

* User-defined categories
* Used for tracking and analytics
* Foundation for future budgeting systems

---

### 🏦 Accounts

* Track multiple account types:

  * Bank accounts
  * Cash
  * Savings
  * Credit cards

* Features:

  * Transfers between accounts
  * Credit card tracking (including due payments)
  * Optional manual/automatic payment tracking

> ⚠️ This is not a banking app. Accounts represent **tracked balances**, not real integrations.

---

### 💰 Balance System

* Global balance overview (across all accounts)
* Ability to inspect individual accounts
* Future-friendly:

  * Optional “focused account view” on home screen

---

### 🎯 Goals

* Create savings goals:

  * Target amount
  * Optional time constraint
* Track progress via transactions
* Transactions can be linked to goals

---

### 📈 Investment Simulation (MVP)

* Simple compound interest calculator
* Adjustable parameters:

  * Initial amount
  * Monthly contributions
  * Interest rate
  * Compounding frequency
  * Inflation adjustment
  * Contribution growth (optional)

---

### 📊 Analytics (MVP)

* Simple and clear charts:

  * Spending by category
  * Income vs expenses
  * Net worth over time

* Focus:

  * Clarity over complexity
  * Quick understanding of financial state

---

### 🔔 Notifications (Planned)

* Recurring transaction reminders
* Payment alerts (e.g. credit card due)
* Goal-related nudges

---

### 🌍 Multi-Currency Support

* Default currency (e.g. EUR)
* Transactions in different currencies
* Automatic conversion based on transaction date
* Accounts may use different currencies

---

## 🧠 Key Concepts

### 📅 Financial Cycles

The app considers user financial cycles instead of strict calendar months.

Example:

* Salary received at end of month
* Rent paid at beginning of next month

The goal is to avoid misleading summaries caused by timing differences.

---

### ⚡ Speed First UX

The app must never feel like a burden.

* Quick add flow (minimal required input)
* Optional advanced fields
* Designed for frequent daily usage

---

### 📊 Insight-Oriented Design

The app is not just for tracking—it is for understanding behavior.

Future direction:

* Spending patterns
* Behavioral insights
* Smart suggestions

---

## 🏗 Architecture

The app follows a **layered architecture with feature-based organization**:

```text
UI (Presentation)
  ↓
ViewModel (State & Logic)
  ↓
Repository (Abstraction)
  ↓
Data Sources
```

### Layers

#### Presentation

* Screens and widgets
* ViewModels (state + UI logic)
* Handles user interaction

#### Domain

* Core entities
* Repository contracts

#### Data

* Repository implementations
* Data sources

---

## 📁 Project Structure

```text
lib/
  core/
    utils/
    constants/

  features/
    auth/
      data/
      domain/
      presentation/

    budget/
      data/
      domain/
      presentation/

  app.dart
  main.dart
```

---

## 🎨 UI / UX Guidelines

### 🧭 Navigation

* Bottom navigation as primary structure
* Suggested sections:

  * Home (overview)
  * Transactions
  * Analytics
  * Settings

---

### 🎯 Design Principles

#### 1. Simplicity First

* Reduce cognitive load
* Prioritize essential actions

#### 2. Speed Over Perfection

* Transactions should take seconds to add

#### 3. Progressive Disclosure

* Show minimal fields by default
* Expand into advanced options when needed

#### 4. Strong Visual Hierarchy

* Highlight key financial data
* Use spacing and typography intentionally

#### 5. Consistency

* Reuse components
* Predictable patterns

---

### 🎨 Visual Style

Inspired by:

* Minimal Apple-like interfaces
* Modern fintech apps (e.g. Nubank)

Guidelines:

* Soft neutral base colors
* Strong primary accent color
* Rounded components
* Clean spacing
* Subtle elevation

---

### 🧩 Component Philosophy

* Build reusable components early
* Prefer composition over duplication
* Maintain consistent spacing system

### 🆔 Identifier Strategy

* All persisted entity IDs must use UUIDs

---

### ⚡ Interaction Design

* Fast, responsive interactions
* Immediate feedback
* Smooth transitions
* Non-intrusive alerts

### ✍️ Microcopy

* Keep labels and helper text brief
* Do not explain obvious UI outcomes
* Prefer silence over redundant confirmations for routine actions

---

## 🪵 Logging

Logging should stay intentional and minimal.

Guidelines:

* Log only useful events, failures, and warnings that help debug real issues
* Prefer meaningful logs around app startup, persistence, and unexpected errors
* Avoid noisy logs for normal UI flow, rebuilds, or routine state changes
* Keep logs concise and easy to scan
* The app should never feel filled with logs just because logging is available

---

### ➕ Transaction UX

* Default: quick input (amount, category, account)
* Optional: “Advanced” section for details
* Goal: reduce friction for daily use

---

## 🛣 Roadmap (Future)

* Advanced budgeting systems
* Smart insights and pattern detection
* Bank statement import
* Shared accounts and budgets
* Offline-first sync
* Location-based suggestions (e.g. recurring places)

---

## 🧪 Development Strategy

* Start with a focused MVP
* Iterate quickly
* Avoid premature complexity

---

## 📌 Notes

This project is designed to evolve over time.

Focus:

1. Strong foundation
2. Excellent usability
3. Gradual feature expansion

---
