# Barnacle — Coding Conventions

Based on [martinlasek/skills](https://github.com/martinlasek/skills) Swift and SwiftUI coding guidelines.

## Folder Structure

Use singular folder names organized by layer:

```
Barnacle/
├── Enum/          — All enums in dedicated files
├── Model/         — Data structs/classes (Model suffix)
├── Store/         — Persistence adapters (KeychainStore, etc.)
├── Service/       — IO wrappers (network, audio, filesystem)
└── View/          — SwiftUI views (one view per file)
    └── Onboarding/
```

- `Model/` is only for data structs/classes. Enums are not models; place enums in `Enum/`.
- `Store/` is for persistence adapters (e.g., UserDefaults, Keychain). Do not place Store types in `Service/`.
- `Shared/` is only for truly cross-feature primitives. Feature-specific types go in their feature folder.

## Enum Rules (Mandatory)

- Every enum lives in its own dedicated file under `Enum/`.
- Blank line between every `case` declaration.
- Blank line after opening brace.

```swift
enum RecordingState {

    case idle

    case recording

    case stopped
}
```

Exception: `UserDefaultsKeys` may be a single file with nested enums.

## Mutation Semantics (Mandatory)

- No `willSet` / `didSet` observers in app code.
- No explicit property `get` / `set` accessors.
- Computed properties are getter-only and pure (no side effects).
- Use `private(set)` only when methods add real behavior beyond plain assignment.
- No no-op mutator wrappers (`setX`, `updateX`) that only assign a value.
- Properties are nouns (state/value), methods are verbs (actions/mutations).
- Framework-managed wrappers (`@State`, `@Published`, `@AppStorage`, `@Environment`) are allowed.

## Property Wrapper Formatting (Mandatory)

- Property wrappers go on their own line, not inline with the declaration.
- Blank line between consecutive stored properties when either uses a wrapper.
- Blank line after type declaration before first member.

```swift
struct MyView: View {

    @Environment(AppConfig.self)
    private var config

    @State
    private var isLoading = false

    var body: some View { ... }
}
```

## Naming (Mandatory)

- lowerCamelCase, no underscores in function or property names.
- Model types use `Model` suffix (e.g., `MessageModel`).
- Service types use `Service` suffix (e.g., `OpenClawService`).
- Store types use `Store` suffix (e.g., `KeychainStore`).
- Never use the name `coordinator` for types, variables, or architecture roles.

## Import Hygiene (Mandatory)

- Add explicit imports for all used types/APIs. Do not rely on transitive imports.

## Multi-line Formatting

- One argument per line for multi-argument calls.
- Prefer `guard` over nested `if` when it reduces indentation.
- For multi-line `if` bindings, place the opening brace on its own line.

## File Headers (Mandatory)

```swift
//
//  FileName.swift
//  Barnacle
//
//  Created by Oleh Titov on DD.MM.YYYY.
//
```

Preserve existing human authorship lines.

## SwiftUI Guidelines

### Layer Responsibilities

- **View**: Declarative UI only, bind to state.
- **ViewModel**: State + orchestration, explicit side-effect methods. Use `final class`.
- **Controller/Dispatcher**: Pure transformations, no IO or UI state.
- **Service**: IO boundary (network, audio, filesystem). Single-purpose, easy to stub.
- **Store**: Thin persistence adapter. No business logic beyond serialization.

### View Rules

- Each SwiftUI view in its own file. No nested/local view types.
- No `private var foo: some View` computed properties — extract to standalone View files.
- Use computed properties only for derived values and small logic helpers, not view subtrees.

### Bindings

- No pass-through `Binding(get:set:)` — use direct bindings for plain state.
- `Binding(get:set:)` only when `set` has intentional behavior (mapping, validation).

### What to Avoid

- Over-engineering (extra layers without value).
- Implicit side effects (`didSet`, global state).
- Generic "manager" classes.
- UI logic in services/dispatchers.
- Cross-layer responsibilities (e.g., store running business logic).

## Build & Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Barnacle.xcodeproj \
  -scheme Barnacle \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -quiet build
```
