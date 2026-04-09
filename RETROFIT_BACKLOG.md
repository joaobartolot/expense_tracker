# Retrofit Backlog

## Purpose

This document captures the remaining retrofit backlog for moving the app toward:

- stronger test coverage
- clearer behavioral contracts
- safer removal of stale or out-of-scope logic
- cleaner alignment with the intended layered architecture

This is not an implementation plan in the low-level sense. It is a scoped backlog for test-definition and follow-up implementation work.

The current retrofit work has already covered a large portion of the `add transaction` create/edit flow. The backlog below focuses on what is still missing, what is likely risky, and what appears to be stale or partially removed behavior.

## Current State

### Areas already covered by retrofit tests

The transaction retrofit already includes explicit coverage for:

- repository create flow
- repository edit flow
- normalization rules
- basic invalid input
- account requirements
- category requirements
- amount input mask behavior
- feature-level failure behavior
- add-transaction integration flow
- minimal removal guardrails for add-transaction transfer/credit-card removal

### What this means

The core `AddTransactionPage` save path is no longer the largest blind spot.

The largest remaining gaps now sit in:

- app-state derivation and orchestration
- delete flows
- transaction browsing/detail/history behavior
- recurring transaction behavior
- transfer and credit-card leftovers outside add transaction
- cross-feature repository/state contracts outside transactions

## Retrofit Goals

The retrofit should continue optimizing for:

1. business rules defined by tests before implementation changes
2. explicit failure behavior
3. atomic persistence behavior
4. single-source-of-truth state rules
5. reduced accidental behavior
6. removal of stale branches that no longer belong to the simplified product scope

## Priority Model

The backlog uses four levels:

- P0: highest-risk gaps or likely regression sources
- P1: important user-facing behavior with significant missing coverage
- P2: important but less urgent support logic
- P3: cleanup and hardening work after critical contracts are covered

## P0 Backlog

### 1. App State Factory Contracts

**Priority:** P0

**Why**

`AppStateFactory` now drives a large amount of feature behavior but has no direct unit coverage. That means several screens currently rely on derived state with very little protection.

**Primary files**

- [lib/app/state/app_state_factory.dart](/home/bartolot/personal/vero/lib/app/state/app_state_factory.dart)
- [lib/app/state/app_state_snapshot.dart](/home/bartolot/personal/vero/lib/app/state/app_state_snapshot.dart)

**Scope**

Define tests for:

- selected period derivation
- account selected-period derivation
- period transaction filtering
- period summary computation
- history transaction filtering
- history sorting
- history search behavior
- account overview derivation
- account transfer summary derivation
- missing conversion count behavior
- global balance conversion exclusion behavior
- rebuild behavior when filters/sort/query change
- rebuild behavior when financial cycle day changes

**Important contract questions**

- whether transfer remains a supported history/account-overview concept
- whether missing conversion data should exclude transactions silently or expose stronger UI state

**Expected outcome**

Derived state becomes test-driven instead of inferred from UI behavior.

### 2. App State Notifier Orchestration

**Priority:** P0

**Why**

`AppStateNotifier` is the real coordination layer across repositories, recurring execution, and derived state. There is currently no focused test coverage around refresh and orchestration behavior.

**Primary file**

- [lib/app/state/app_state_notifier.dart](/home/bartolot/personal/vero/lib/app/state/app_state_notifier.dart)

**Scope**

Define tests for:

- initial refresh behavior
- successful refresh behavior
- refresh failure behavior and `loadError`
- queued refresh behavior while already refreshing
- account save/edit delegation
- transaction save/edit delegation
- category save/edit delegation
- recurring transaction save/edit delegation
- delete-account guard behavior when linked transactions exist
- delete-category guard behavior when linked transactions exist
- delete-with-transactions behavior
- automatic recurring execution integration during refresh

**Expected outcome**

The app-state layer becomes a protected boundary instead of a large untested coordinator.

### 3. Delete Flow Contracts

**Priority:** P0

**Why**

Create/edit behavior is now covered, but delete behavior is still a major hole. Delete bugs are usually high-risk because they can corrupt user data or create confusing UI state.

**Primary files**

- [lib/features/transactions/presentation/pages/transaction_detail_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/transaction_detail_page.dart)
- [lib/features/transactions/presentation/pages/home_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/home_page.dart)
- [lib/features/transactions/presentation/pages/transaction_history_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/transaction_history_page.dart)
- [lib/features/transactions/domain/services/transaction_balance_service.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/services/transaction_balance_service.dart)

**Scope**

Define tests for:

- delete confirmation flow
- cancel behavior
- successful delete
- delete failure behavior
- no partial UI success on delete failure
- detail-page delete behavior
- delete from home list
- delete from history list
- delete propagation through app state
- visible-state update after delete success

**Expected outcome**

Delete behavior becomes as explicit and safe as create/edit behavior.

## P1 Backlog

### 4. Transaction History Screen Contracts

**Priority:** P1

**Why**

The history page holds filter, sort, search, pagination, and contextual actions. It currently has no dedicated widget contract coverage.

**Primary file**

- [lib/features/transactions/presentation/pages/transaction_history_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/transaction_history_page.dart)

**Scope**

Define tests for:

- loading state
- empty state labels per filter
- search query behavior
- sort picker behavior
- filter picker behavior
- page-size and load-more behavior
- transaction tap opens details
- long-press action menu behavior
- edit action launches edit flow
- delete action launches delete flow

**Important note**

If transfer is being removed from the simplified product surface, the history filter contract needs a product decision first because `Transfers` still exists in history UI/state.

### 5. Home Screen Transaction Contracts

**Priority:** P1

**Why**

The home page is likely one of the most used screens, but it still depends mostly on indirect coverage.

**Primary file**

- [lib/features/transactions/presentation/pages/home_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/home_page.dart)

**Scope**

Define tests for:

- add button behavior with and without accounts
- empty period state behavior
- period transaction grouping
- visible summary cards
- balance subtitle when conversions are missing
- transaction tap behavior
- long-press action menu behavior
- `View more` visibility and behavior

### 6. Transaction Detail Contracts

**Priority:** P1

**Why**

The detail page is the main per-transaction inspection surface, and it still contains logic for categories, accounts, foreign-currency display, edit, and delete.

**Primary file**

- [lib/features/transactions/presentation/pages/transaction_detail_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/transaction_detail_page.dart)

**Scope**

Define tests for:

- transaction missing state
- category present vs missing behavior
- foreign-currency snapshot display
- edit action behavior
- delete confirmation behavior
- delete success behavior
- delete failure behavior

**Important note**

The detail page still contains transfer and credit-card-specific rendering branches. Those either need direct guardrails or later cleanup.

### 7. Aggregation and Balance Services

**Priority:** P1

**Why**

Derived balances and converted transaction amounts are financially sensitive. They need direct unit coverage rather than only indirect UI verification.

**Primary files**

- [lib/features/transactions/domain/services/transaction_aggregation_service.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/services/transaction_aggregation_service.dart)
- [lib/features/accounts/domain/services/balance_overview_service.dart](/home/bartolot/personal/vero/lib/features/accounts/domain/services/balance_overview_service.dart)

**Scope**

Define tests for:

- conversion into base currency
- same-currency passthrough behavior
- missing-rate handling
- effective balance calculation from transactions
- opening-balance inclusion
- global balance exclusion of accounts with missing conversion rates

## P2 Backlog

### 8. Recurring Schedule Contracts

**Priority:** P2

**Why**

Recurring schedule logic is pure business logic and should be cheap to test, but it is currently unprotected.

**Primary file**

- [lib/features/recurring_transactions/domain/services/recurring_schedule_service.dart](/home/bartolot/personal/vero/lib/features/recurring_transactions/domain/services/recurring_schedule_service.dart)

**Scope**

Define tests for:

- next due occurrence
- due occurrences generation
- latest due occurrence
- paused behavior
- day interval behavior
- week interval behavior
- month interval behavior, including end-of-month anchoring
- year interval behavior, including leap/year edge cases
- overview status derivation: paused, overdue, due today, due soon, upcoming

### 9. Recurring Execution Contracts

**Priority:** P2

**Why**

Recurring execution writes real transactions. It needs strong safeguards for automatic processing and manual confirmation behavior.

**Primary file**

- [lib/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart](/home/bartolot/personal/vero/lib/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart)

**Scope**

Define tests for:

- paused recurring transactions do not execute
- automatic recurring transactions create due entries
- initial automatic execution behavior
- multiple due occurrences behavior
- confirm-next-due-occurrence behavior
- not-yet-due confirmation behavior
- last processed occurrence updates correctly
- failure behavior when save fails
- failure behavior when recurring update fails

**Important note**

This service still builds transfer and credit-card-related transactions. That should be explicitly reviewed against the current product direction.

### 10. Settings / Period Interaction

**Priority:** P2

**Why**

Financial cycle day and default currency affect state derivation across the app. These are high-leverage settings and deserve explicit contract tests.

**Primary areas**

- [lib/app/state/app_state_factory.dart](/home/bartolot/personal/vero/lib/app/state/app_state_factory.dart)
- [lib/features/settings/domain/models/app_settings.dart](/home/bartolot/personal/vero/lib/features/settings/domain/models/app_settings.dart)

**Scope**

Define tests for:

- selected period changes when financial cycle day changes
- account selected periods remain coherent after setting changes
- base currency changes affect converted totals but not persisted transaction currency

### 11. Linked-Entity Delete Rules

**Priority:** P2

**Why**

The app already contains linked-entity deletion guards, but they are largely untested and could regress.

**Primary file**

- [lib/app/state/app_state_notifier.dart](/home/bartolot/personal/vero/lib/app/state/app_state_notifier.dart)

**Scope**

Define tests for:

- category delete blocked by linked transactions
- category delete blocked by linked recurring transactions
- account delete blocked by linked transactions
- account delete blocked by linked recurring transactions
- category/account delete-with-transactions behavior

## P3 Backlog

### 12. Transaction Model Contracts

**Priority:** P3

**Why**

`TransactionItem` carries a lot of behavior, especially because transfer and foreign-currency fields still remain in the model.

**Primary file**

- [lib/features/transactions/domain/models/transaction_item.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/models/transaction_item.dart)

**Scope**

Define tests for:

- `copyWith`
- `toMap` / `fromMap`
- equality / hashCode
- `hasForeignCurrency`
- `balanceChanges`
- `linkedAccountIds`
- `primaryAccountId` / `secondaryAccountId`

**Important note**

If transfer is no longer part of the intended product surface, these tests should be written only after deciding whether the model itself is being simplified or whether transfer remains as legacy data support.

### 13. App State Snapshot Helper Contracts

**Priority:** P3

**Why**

Snapshot helpers are heavily used by UI and delete guard logic.

**Primary file**

- [lib/app/state/app_state_snapshot.dart](/home/bartolot/personal/vero/lib/app/state/app_state_snapshot.dart)

**Scope**

Define tests for:

- `transactionsForCategory`
- `transactionsForAccount`
- `hasLinkedTransactionsForAccount`
- `hasLinkedTransactionsForCategory`
- `hasLinkedRecurringTransactionsForAccount`
- `hasLinkedRecurringTransactionsForCategory`
- `convertedAmountForTransaction`
- `totalForTransactions`
- `missingConversionCountForTransactions`

### 14. Repository Contracts Outside Transactions

**Priority:** P3

**Why**

Transaction repository coverage is now relatively strong. Other repositories still have little or no direct contract coverage.

**Primary files**

- [lib/features/accounts/data/hive_account_repository.dart](/home/bartolot/personal/vero/lib/features/accounts/data/hive_account_repository.dart)
- [lib/features/categories/data/hive_category_repository.dart](/home/bartolot/personal/vero/lib/features/categories/data/hive_category_repository.dart)
- [lib/features/recurring_transactions/data/hive_recurring_transaction_repository.dart](/home/bartolot/personal/vero/lib/features/recurring_transactions/data/hive_recurring_transaction_repository.dart)
- [lib/features/settings/data/hive_settings_repository.dart](/home/bartolot/personal/vero/lib/features/settings/data/hive_settings_repository.dart)

**Scope**

Define tests for:

- create/update/delete contracts
- persistence invariants
- ID behavior
- no partial write behavior
- handling of missing or malformed stored data where relevant

## Leftover Logic and Cleanup Candidates

These are not necessarily immediate implementation tasks, but they should be tracked because they affect test strategy and scope decisions.

### A. Transfer and Credit-Card Logic Still Exists Outside Add Transaction

Although add transaction has been simplified, transfer and credit-card-specific logic still exists in multiple places.

**Observed areas**

- [lib/features/transactions/domain/models/transaction_item.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/models/transaction_item.dart)
- [lib/features/transactions/domain/services/transaction_balance_service.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/services/transaction_balance_service.dart)
- [lib/features/transactions/data/hive_transaction_repository.dart](/home/bartolot/personal/vero/lib/features/transactions/data/hive_transaction_repository.dart)
- [lib/features/transactions/presentation/pages/transaction_detail_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/transaction_detail_page.dart)
- [lib/features/transactions/presentation/pages/transaction_history_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/transaction_history_page.dart)
- [lib/features/transactions/presentation/pages/home_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/home_page.dart)
- [lib/features/accounts/presentation/pages/account_overview_page.dart](/home/bartolot/personal/vero/lib/features/accounts/presentation/pages/account_overview_page.dart)
- [lib/features/accounts/domain/services/credit_card_overview_service.dart](/home/bartolot/personal/vero/lib/features/accounts/domain/services/credit_card_overview_service.dart)
- [lib/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart](/home/bartolot/personal/vero/lib/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart)

**Why this matters**

The current product direction appears to be simplifying add transaction toward income/expense only, but the wider app still models and renders transfer behavior.

This needs a deliberate product/architecture decision:

- keep transfer as a broader app concept and only exclude it from add transaction
- or continue removal across the wider feature set

**Recommended action**

Add a dedicated cleanup track after the next test waves, with narrow guardrail tests before any broader removal.

### B. Stale Compatibility Constructors

`AddTransactionPage.transferFromAccount(...)` and `AddTransactionPage.creditCardPayment(...)` still exist as compatibility aliases.

**Primary file**

- [lib/features/transactions/presentation/pages/add_transaction_page.dart](/home/bartolot/personal/vero/lib/features/transactions/presentation/pages/add_transaction_page.dart)

**Why this matters**

They may be harmless as compatibility shims, but they also keep the old mental model alive and may hide leftover scope drift.

### C. Unused or Weak Abstractions

**Observed candidates**

- `previousTransaction` parameter in `TransactionBalanceService.saveTransaction(...)` is currently not used
- `existingTransaction` and `currentAccounts` parameters in delete methods appear unused in practice
- validation remains duplicated between service and repository

**Why this matters**

These are likely signs of unfinished refactors or earlier design intent that no longer matches the current architecture.

**Recommended action**

Do not remove these immediately. First add orchestration and delete tests so the real contract is explicit.

### D. Money Model Still Uses `double`

The tests now lock behavior to cent-like rounding, but the domain model still uses `double` for persisted monetary values.

**Primary files**

- [lib/features/transactions/domain/models/transaction_item.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/models/transaction_item.dart)
- [lib/features/transactions/domain/services/transaction_balance_service.dart](/home/bartolot/personal/vero/lib/features/transactions/domain/services/transaction_balance_service.dart)
- [lib/features/transactions/data/hive_transaction_repository.dart](/home/bartolot/personal/vero/lib/features/transactions/data/hive_transaction_repository.dart)

**Why this matters**

This is a structural correctness risk, especially for long-term financial accuracy.

**Recommended action**

Treat a `double` to integer-cents migration as a separate, explicitly tested retrofit phase. Do not mix it into unrelated coverage work.

## Recommended Execution Order

### Wave 1

- App state factory tests
- App state notifier tests
- delete-flow tests

### Wave 2

- transaction history tests
- home page tests
- transaction detail tests
- aggregation and balance-service tests

### Wave 3

- recurring schedule tests
- recurring execution tests
- linked-entity delete guard tests

### Wave 4

- model and snapshot helper tests
- repository tests outside transactions

### Wave 5

- transfer/credit-card cleanup guardrails outside add transaction
- money-model migration guardrails if the project decides to eliminate `double`

## Test-Definition Guidance

For the remaining retrofit work:

- prefer small suites that define one behavioral contract each
- separate unit/service/repository tests from widget and integration tests
- keep feature-level failure behavior explicit
- do not silently convert stale behavior into test contracts unless it is deliberately approved
- when a behavior may be a legacy artifact, write it down as an ambiguity first

## Success Criteria

The retrofit can be considered substantially complete when:

- the app-state layer has direct tests
- delete behavior is covered end to end
- browsing/detail/history contracts are explicit
- recurring execution is protected
- stale transfer/credit-card logic has either been intentionally retained or intentionally removed
- remaining financial correctness risks are isolated and tracked, especially the money-type model

## Suggested Next Task

If continuing immediately, the strongest next step is:

1. define `AppStateFactory` tests
2. define `AppStateNotifier` tests
3. define delete-flow tests

That sequence will close the largest remaining untested logic surfaces before moving into cleanup and lower-level hardening.
