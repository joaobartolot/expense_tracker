# AGENTS.md

## CRITICAL RULE: README FIRST

The README.md file is the single source of truth for this project.

You MUST:
- Read README.md completely before any action
- Use it to guide all decisions
- Re-check it if a task is unclear

You MUST NOT:
- Assume project structure without checking README.md
- Run commands before consulting README.md
- Modify code in ways that contradict README.md

There is no need to write tests unless the user explicitly asks for them.

If README.md is missing or insufficient:
→ STOP and ask the user for clarification

## Project
Flutter application.

## Environment
- Use the locally installed Flutter SDK from PATH.
- Assume `flutter`, `dart`, and `adb` are available in the shell.
- Prefer project-local commands; do not modify global SDKs unless asked.

## First steps
1. Run `flutter --version`
2. Run `flutter doctor -v`
3. Run `flutter pub get`

## Validation
Before finishing a task, run:
1. `dart format .`
2. `flutter analyze`

## Android
- Prefer Gradle files already checked into the repo.
- Do not upgrade AGP, Kotlin, Gradle, or compileSdk unless asked.
- If Android build issues occur, inspect `android/build.gradle*`, `android/app/build.gradle*`, `gradle.properties`, and `settings.gradle*`.

## Codegen
If the project uses generated files, run:
- `dart run build_runner build --delete-conflicting-outputs`

## Safety
- Ask before changing signing configs, package IDs, or release settings.