# Retrofit Checklist

This file is the execution-oriented companion to [RETROFIT_BACKLOG.md](/home/bartolot/personal/vero/RETROFIT_BACKLOG.md).

Use it as a practical checklist for test-definition, implementation, and cleanup work during the retrofit.

## How to use this file

- Check an item only when its relevant tests exist and the intended scope is covered.
- For implementation items, check them only when the related tests pass.
- Do not treat this file as the source of behavioral truth; use the test suites for that.
- Keep scope narrow. Add new checklist items instead of broadening existing ones silently.

## Phase 0: Already Covered

- [x] Repository create flow tests for transactions
- [x] Repository edit flow tests for transactions
- [x] Currency normalization tests for transactions
- [x] Basic invalid-input tests for add transaction
- [x] Account requirement tests for add transaction
- [x] Category requirement tests for add transaction
- [x] Amount input behavior tests for add transaction
- [x] Feature-level failure behavior tests for add transaction
- [x] Add-transaction integration flow tests
- [x] Minimal removal guardrail tests for add transaction
- [x] Phase 1 implementation for repository create + normalization + basic validation
- [x] Repository edit-flow implementation
- [x] Failure-behavior harness repair
- [x] Failure-behavior implementation validation
- [x] Account requirement implementation
- [x] Category requirement implementation
- [x] Removal of out-of-scope add-transaction logic in the active add flow

## Phase 1: App State Core

### AppStateFactory tests

- [x] Add unit tests for selected-period derivation
- [x] Add unit tests for account selected-period derivation
- [x] Add unit tests for period transaction filtering
- [x] Add unit tests for period summary computation
- [x] Add unit tests for history filter behavior
- [x] Add unit tests for history sort behavior
- [x] Add unit tests for history search behavior
- [x] Add unit tests for account overview derivation
- [x] Add unit tests for account transfer summary derivation
- [x] Add unit tests for missing conversion count behavior
- [x] Add unit tests for rebuild-derived-state behavior

### AppStateNotifier tests

- [x] Add unit tests for initial refresh behavior
- [x] Add unit tests for successful refresh behavior
- [x] Add unit tests for refresh failure propagation
- [x] Add unit tests for queued refresh behavior
- [x] Add unit tests for saveTransaction delegation
- [x] Add unit tests for saveAccount delegation
- [x] Add unit tests for saveCategory delegation
- [x] Add unit tests for recurring save delegation
- [x] Add unit tests for delete-account linked-entity guards
- [x] Add unit tests for delete-category linked-entity guards
- [x] Add unit tests for delete-with-transactions behavior
- [x] Add unit tests for recurring auto-processing during refresh

### App-state implementation pass

- [x] Implement any missing AppStateFactory behavior required by the new tests
- [x] Implement any missing AppStateNotifier behavior required by the new tests
- [x] Validate relevant unit suites are green

## Phase 2: Delete Contracts

### Transaction delete tests

- [x] Add detail-page delete tests
- [x] Add home-page delete tests
- [x] Add history-page delete tests
- [x] Add delete cancel-behavior tests
- [x] Add delete success-behavior tests
- [x] Add delete failure-behavior tests
- [x] Add no-partial-success / no-corruption delete tests

### Delete implementation pass

- [x] Implement any missing delete behavior required by the tests
- [x] Validate delete-related widget/integration suites are green

## Phase 3: Transaction Browsing Surfaces

### Transaction history tests

- [x] Add widget tests for loading state
- [x] Add widget tests for empty-state labels
- [x] Add widget tests for search query behavior
- [x] Add widget tests for sort picker behavior
- [x] Add widget tests for filter picker behavior
- [x] Add widget tests for pagination/load-more behavior
- [x] Add widget tests for transaction tap behavior
- [x] Add widget tests for long-press action menu behavior

### Home page tests

- [x] Add widget tests for add-button gating when no accounts exist
- [x] Add widget tests for empty-period state behavior
- [x] Add widget tests for transaction grouping behavior
- [x] Add widget tests for balance subtitle when conversions are missing
- [x] Add widget tests for transaction interaction behavior
- [x] Add widget tests for `View more` behavior

### Transaction detail tests

- [x] Add widget tests for missing-transaction state
- [x] Add widget tests for category details navigation behavior
- [x] Add widget tests for foreign-currency snapshot display behavior
- [x] Add widget tests for edit action behavior
- [x] Add widget tests for delete action behavior

### Browsing-surface implementation pass

- [x] Implement any missing history behavior required by tests
- [x] Implement any missing home-page behavior required by tests
- [x] Implement any missing detail-page behavior required by tests
- [x] Validate relevant widget suites are green

## Phase 4: Financial Derivation and Aggregation

### Aggregation and balance tests

- [x] Add unit tests for transaction aggregation same-currency behavior
- [x] Add unit tests for transaction aggregation missing-rate behavior
- [x] Add unit tests for transaction aggregation mixed-currency behavior
- [x] Add unit tests for effective-balance calculation
- [x] Add unit tests for opening-balance inclusion
- [x] Add unit tests for missing-account conversion behavior in global balance

### Financial derivation implementation pass

- [x] Implement any missing aggregation behavior required by tests
- [x] Implement any missing balance-overview behavior required by tests
- [x] Validate relevant unit suites are green

## Phase 5: Recurring Transactions

### Recurring schedule tests

- [x] Add unit tests for next due occurrence
- [x] Add unit tests for due occurrences generation
- [x] Add unit tests for latest due occurrence
- [x] Add unit tests for paused behavior
- [x] Add unit tests for day interval behavior
- [x] Add unit tests for week interval behavior
- [x] Add unit tests for month interval anchoring behavior
- [x] Add unit tests for year interval anchoring behavior
- [x] Add unit tests for overview status derivation

### Recurring execution tests

- [x] Add unit tests for automatic recurring execution
- [x] Add unit tests for initial automatic execution behavior
- [x] Add unit tests for multiple due occurrences
- [x] Add unit tests for confirm-next-due-occurrence behavior
- [x] Add unit tests for not-yet-due behavior
- [x] Add unit tests for last-processed-occurrence updates
- [x] Add unit tests for failure atomicity when transaction save fails
- [x] Add unit tests for failure behavior when recurring update fails

### Recurring implementation pass

- [x] Implement any missing recurring behavior required by tests
- [x] Validate recurring unit suites are green

## Phase 6: Linked-Entity Rules

### Account/category linked-entity tests

- [x] Add tests for category delete blocked by linked transactions
- [x] Add tests for category delete blocked by linked recurring transactions
- [x] Add tests for account delete blocked by linked transactions
- [x] Add tests for account delete blocked by linked recurring transactions
- [x] Add tests for delete-account-with-transactions behavior
- [x] Add tests for delete-category-with-transactions behavior

### Linked-entity implementation pass

- [x] Implement any missing linked-entity behavior required by tests
- [x] Validate relevant unit/integration suites are green

## Phase 7: Model and Helper Hardening

### TransactionItem tests

- [x] Add tests for `copyWith`
- [x] Add tests for `toMap` / `fromMap`
- [x] Add tests for equality / hashCode
- [x] Add tests for `hasForeignCurrency`
- [x] Add tests for `balanceChanges`
- [x] Add tests for linked-account helper behavior

### AppStateSnapshot helper tests

- [x] Add tests for `transactionsForCategory`
- [x] Add tests for `transactionsForAccount`
- [x] Add tests for linked-transaction helper behavior
- [x] Add tests for linked-recurring helper behavior
- [x] Add tests for `convertedAmountForTransaction`
- [x] Add tests for `totalForTransactions`
- [x] Add tests for missing-conversion helper behavior

### Model/helper implementation pass

- [x] Implement any missing model/helper behavior required by tests
- [x] Validate relevant unit suites are green

## Phase 8: Repository Coverage Outside Transactions

### Repository test coverage

- [x] Add account repository contract tests
- [x] Add category repository contract tests
- [x] Add recurring transaction repository contract tests
- [x] Add settings repository contract tests

### Repository implementation pass

- [x] Implement any missing repository behavior required by tests
- [x] Validate repository suites are green

## Phase 9: Leftover Transfer / Credit-Card Cleanup

### Guardrails before wider cleanup

- [x] Add guardrail tests for transaction history if transfer is being removed from visible product scope
- [x] Add guardrail tests for transaction detail if transfer/credit-card rendering is being removed
- [x] Add guardrail tests for home-page transfer labeling if transfer is being removed
- [x] Add guardrail tests for account-overview transfer/pay-card entry points if they are being removed
- [x] Add guardrail tests for recurring execution if transfer generation is being removed there too

### Cleanup decisions

- [x] Decide whether transfer remains a supported domain concept
- [x] Decide whether credit-card-specific transaction behavior remains supported
- [x] Decide whether compatibility constructors on `AddTransactionPage` should remain or be removed
- [x] Decide whether history filter should still expose `Transfers`
- [x] Decide whether account overview should still expose `Transfer` / `Pay card`

### Cleanup implementation pass

- [x] Retain the approved leftover transfer/credit-card logic and avoid unapproved removal
- [x] Validate all guardrail suites are green

## Phase 10: Money Model Hardening

### Migration guardrails

- [x] Defer integer-cents domain guardrails while `double` remains the approved persisted model
- [x] Defer integer-cents repository persistence guardrails while `double` remains the approved persisted model
- [x] Defer integer-cents normalization guardrails while `double` remains the approved persisted model
- [x] Defer integer-cents aggregation guardrails while `double` remains the approved persisted model

### Money-model migration

- [x] Decide whether `double` remains acceptable for persisted money
- [x] Conclude that no dedicated money-model migration is required in this retrofit
- [x] Validate all affected transaction, aggregation, and state suites are green

## Cross-Cutting Cleanup

- [x] Review duplicated validation between service and repository
- [x] Review unused `previousTransaction` parameter in transaction save flow
- [x] Review unused delete-flow parameters in transaction balance service
- [x] Review stale compatibility entry points after cleanup phases
- [x] Review any skipped tests and either make them representable or consciously retire them

## Final Retrofit Completion Checklist

- [x] All approved retrofit test suites exist
- [x] All approved retrofit implementation phases are complete
- [x] Relevant unit tests pass
- [x] Relevant widget tests pass
- [x] Relevant integration tests pass, or no dedicated integration suite currently exists
- [x] Out-of-scope legacy behavior has either been removed or explicitly retained
- [x] Remaining technical debt is documented and intentionally deferred
