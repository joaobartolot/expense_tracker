# AGENTS.md

## CRITICAL RULE: README FIRST

`README.md` is the single source of truth for this project.

You MUST:
- Read `README.md` completely once at the start of each session, before taking action.
- Re-read `README.md` only if:
  - it changes during the session, or
  - the current task is unclear and requires clarification from project documentation.
- Use `README.md` to guide all decisions.

You MUST NOT:
- Assume project structure without checking `README.md` at least once per session.
- Run project commands before the initial README check for that session.
- Modify code in ways that contradict `README.md`.

There is no need to write tests unless the user explicitly asks for them.

If `README.md` is missing or insufficient:
→ STOP and ask the user for clarification.

## Project
Flutter application.

## Environment
- Use the locally installed Flutter SDK from PATH.
- Assume `flutter`, `dart`, and `adb` are available in the shell.
- Prefer project-local commands; do not modify global SDKs unless asked.

## First steps

Run these once at the start of each session, not before every step:
1. `flutter --version`
2. `flutter doctor -v`
3. `flutter pub get`

Re-run them only if:
- the environment appears to have changed,
- dependencies/configuration changed in a way that makes them relevant, or
- a command failure indicates they should be re-checked.

## Validation

Before finishing a task, run:
1. `dart format .`
2. `flutter analyze`

Only run additional validation steps if the user asks for them or the task clearly requires them.

## Android
- Prefer Gradle files already checked into the repo.
- Do not upgrade AGP, Kotlin, Gradle, or compileSdk unless asked.
- If Android build issues occur, inspect `android/build.gradle*`, `android/app/build.gradle*`, `gradle.properties`, and `settings.gradle*`.

## Codegen
If the project uses generated files, run:
- `dart run build_runner build --delete-conflicting-outputs`

Only run code generation when needed by the task or when source inputs affecting generated files have changed.

## Safety
- Ask before changing signing configs, package IDs, or release settings.