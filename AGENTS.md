# AGENTS.md

## Project Overview

Vero is a Flutter-based personal finance application focused on fast and intuitive expense tracking.

This is a single-user-first app designed for performance, simplicity, and future extensibility.

Key characteristics:

- Local-first architecture
- Clean layered architecture (UI → ViewModel → Repository → DataSource)
- No external backend required for core functionality
- Designed for future migration (Firestore / SQL)
- Focus on fast UX and minimal friction

The app is not a banking integration system. It tracks user-defined financial data locally.

---

## Source of Truth

AGENTS.md is the operational source of truth for how to work on this project.

README.md provides product and domain context only.

The agent may read README.md for understanding, but must not depend on it to execute tasks.

---

## Environment

- Use Flutter from PATH
- Assume `flutter`, `dart`, and `adb` are available
- Do not modify global SDKs unless explicitly asked

---

## Session Setup

Run once per session:

- `flutter pub get`

Re-run only if dependencies or configuration change.

---

## Validation

Before finishing a task:

- `dart format .`
- `flutter analyze`

Before completing implementation or committing:

- Run relevant test suites
- Ensure tests pass

---

## Architecture Rules

The project follows a layered architecture:

```
UI (Presentation)
  ↓
ViewModel
  ↓
Repository
  ↓
Data Source
```

Rules:

- UI must never access DataSources directly
- UI must only communicate with ViewModels
- ViewModels handle UI state and logic
- Repositories handle business logic
- DataSources handle persistence only

Domain models must be pure:

- No Hive
- No Firebase
- No external dependencies

---

## Project Structure

```
lib/
  core/
  features/
    <feature>/
      data/
      domain/
      presentation/
test/
  unit/
  integration/
```

Rules:

- Features must be isolated
- Do not mix layers
- Do not place business logic in UI

---

## State Management

- Shared state must have a single source of truth
- Do not duplicate state across screens
- Derived values must be centralized
- Widgets must not hold business state
- Widgets may hold ephemeral UI state only

---

## Data and Persistence

- All persisted IDs must be UUIDs
- Repository is the only layer exposed to UI
- DataSources must not contain business logic
- Validation belongs in repository
- Sorting and filtering belong in repository unless purely mechanical

---

## Coding Guidelines

- Prefer composition over duplication
- Keep widgets small and reusable
- Avoid unnecessary abstractions
- Keep code simple and readable
- Follow existing patterns before introducing new ones

---

## Test-First Development Workflow

This project follows a strict test-first workflow for feature development.

Test cases may be provided incrementally across multiple prompts.

Workflow:

1. The user starts describing a feature and its test cases
2. The agent implements tests only
3. The user may continue adding more test cases in subsequent prompts
4. The agent continues extending the test suite without implementing business logic
5. Only after the user explicitly indicates that test definition is complete, implementation may begin

The agent must assume that test definition is ongoing unless explicitly told otherwise.

---

## Test Definition Mode

While in test-definition mode:

- Implement only the requested tests
- Do not implement production business logic
- Do not “helpfully” implement missing behavior
- Do not infer or add extra cases beyond what the user specifies
- Do not suggest implementation steps
- Focus strictly on translating user input into tests

Tests may fail during this phase. This is expected.

---

## Transition to Implementation

Implementation must only begin when the user clearly signals it.

Examples of valid signals:

- "tests are complete"
- "you can implement now"
- "start implementing"

Until such a signal is given:

- Do not write business logic
- Do not modify production code beyond what is strictly required for test compilation (e.g. interfaces, placeholders)

---

## Implementation Rules

Once implementation is authorized:

- Use tests as the source of truth
- Implement only what is required for tests to pass
- Do not expand scope beyond defined test cases
- Do not refactor unrelated code

---

## Test Scope Guidelines

Unit tests should focus on:

- Repository rules
- ViewModel behavior
- Domain validation
- Derived values
- Edge cases and invalid inputs

Integration tests should focus on:

- Feature flows across layers
- Screen-level behavior when applicable
- Persistence through repositories
- Wiring between components

---

## Test Naming

Use descriptive test names:

- `<methodBeingTested>_<expectedBehavior>`
- `<methodBeingTested>_<invalidCondition>`

Examples (style reference only):

- `addTransaction_createsTransactionWhenInputIsValid`
- `addTransaction_rejectsEmptyName`

---

## Feature Implementation Order

1. User defines test cases
2. Agent implements tests
3. Tests are completed
4. Implementation begins
5. Validation is run
6. Tests are executed again before commit

---

## Running Tests

Before committing:

- Run all relevant unit tests
- Run all relevant integration tests
- Ensure all tests pass

A feature is not complete if its tests are failing.

---

## Codegen

If needed:

- `dart run build_runner build --delete-conflicting-outputs`

Run only when required.

---

## Android

- Do not upgrade Gradle, Kotlin, AGP, or SDK unless asked
- Inspect existing Gradle files first when issues occur

---

## Safety

Ask before changing:

- Signing configs
- Package IDs
- Release settings
- Major dependencies
- Build or deployment configurations

---

## Anti-Patterns

- Do not put business logic in widgets
- Do not access DataSources from UI
- Do not duplicate shared state
- Do not introduce unnecessary complexity
- Do not add dependencies without clear need
- Do not implement business logic during test-definition phase
- Do not modify unrelated code

---

## Commit Messages

Use conventional commit prefixes:

- `feat:`
- `fix:`
- `refactor:`
- `test:`
- `docs:`
- `chore:`
- `wip:`

Keep messages short, clear, and scoped to the change.