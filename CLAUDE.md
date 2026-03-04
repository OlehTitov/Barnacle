# Barnacle

## What This Is

An open-source iOS voice client for OpenClaw (GPL-3.0). Think walkie-talkie for your AI assistant — tap to talk, get a voice response. Supports ElevenLabs and OpenAI TTS, on-device transcription, Siri wake word, car Bluetooth.

## Architecture

```
BarnacleApp.swift          — App entry, theme, onboarding gate
  └─ MainView              — Primary UI (big tap button, waveform, messages)
      └─ ConversationService — Orchestrates the full voice turn cycle
          ├─ VoiceRecorder        — AVAudioEngine mic capture + silence detection
          ├─ FluidTranscriber     — On-device ASR (FluidAudio/Parakeet TDT)
          ├─ ScribeTranscriber    — Apple Speech (SFSpeechRecognizer) fallback
          ├─ Transcriber          — Legacy Apple transcriber
          ├─ WhisperService       — OpenAI Whisper API transcription
          ├─ TTSPlayer            — Full-buffer TTS playback (AVAudioPlayer)
          ├─ StreamingTTSPlayer   — Chunked streaming TTS playback
          ├─ OpenClawService      — HTTP client for OpenClaw /v1/responses
          └─ GreetingCacheService — Caches first greeting audio for instant playback
```

### Turn Cycle (ConversationService.runTurn)
1. Activate audio session (single source of truth — see Audio section)
2. Optional: play cached greeting
3. Record user speech via chosen transcription engine
4. Send transcript to OpenClaw via SSE streaming
5. Stream response text chunks to TTS
6. Play audio response
7. If continuous mode: loop back to step 3

## Audio Session — CRITICAL

**Single owner:** `ConversationService.activateAudioSession()` is the ONLY place the audio session category is set. All recorders and players use `skipAudioSessionSetup: true`.

```swift
// ConversationService.swift — activateAudioSession()
.playAndRecord, mode: .voiceChat,
options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
```

**Why `.voiceChat` mode:** Enables hardware echo cancellation. Without it, the speaker output feeds back into the mic during continuous conversation. DO NOT change to `.default` mode — echo will return.

**Bluetooth routing:** `.allowBluetoothA2DP` routes media audio to car stereos and Bluetooth speakers. `.allowBluetoothHFP` enables hands-free profile for mic input from car systems. Both are needed for full car Bluetooth support (mic from car, audio to car).

**Rules:**
- NEVER set audio session category in VoiceRecorder, TTSPlayer, StreamingTTSPlayer, or any transcriber when called from ConversationService
- The `skipAudioSessionSetup` parameter exists specifically for this — always pass `true` from ConversationService
- VoiceRecorder has its own session setup ONLY for standalone use outside ConversationService
- If audio routing breaks, check here FIRST — it's almost always a session category/mode issue

## Transcription Engines

Three engines, user-selectable in settings:

| Engine | Class | How it works |
|--------|-------|-------------|
| FluidAudio | `FluidTranscriber` | On-device Parakeet TDT model. Best accuracy. Needs model download (~200MB). Has its own VAD (VadManager). |
| Scribe | `ScribeTranscriber` | Apple SFSpeechRecognizer with on-device VAD. Good fallback. |
| Whisper | `WhisperService` | Records audio file → sends to OpenAI Whisper API. Most accurate but adds network latency. |

**VAD (Voice Activity Detection):** FluidTranscriber and ScribeTranscriber both have built-in VAD for end-of-utterance detection. VoiceRecorder has its own simple silence detection (power level threshold + 3-second timeout) used by the Whisper path.

## TTS

Two playback modes:
- `TTSPlayer` — Downloads full audio, then plays. Simpler, used for non-streaming responses.
- `StreamingTTSPlayer` — Receives text chunks via `sendTextChunk()`, fetches audio per chunk, queues playback. Used during SSE streaming for lower latency.

Two providers: ElevenLabs (default) and OpenAI. Configured via `AppConfig` / `TTSConfig`.

## Key Files

| File | Purpose |
|------|---------|
| `ConversationService.swift` | Main orchestrator — start here for any flow changes |
| `AppConfig.swift` (in Model/) | All user settings — TTS provider, voice, theme, API keys |
| `TTSConfig.swift` (in Model/) | TTS-specific config extracted from AppConfig |
| `MainView.swift` | Primary UI — tap button, waveform visualization, message list |
| `OpenClawService.swift` | SSE streaming client for /v1/responses endpoint |
| `SSEParser.swift` | Server-Sent Events parser |
| `TextChunkBuffer.swift` | Buffers streaming text into speakable chunks for TTS |

## Patterns to Follow

- **@Observable** for all service/model classes (not Combine, not ObservableObject)
- **No Combine** — use async/await and AsyncStream throughout
- **Single file per view** — no nested view types
- **Enums get their own files** in `Enum/` directory
- **No didSet/willSet** — use explicit methods for mutations with side effects
- **Property wrappers on their own line** with blank line between properties

## Don'ts

- Don't set AVAudioSession anywhere except `ConversationService.activateAudioSession()`
- Don't use `.record` category — always `.playAndRecord` (need both mic and speaker)
- Don't use `.measurement` mode from ConversationService — that disables echo cancellation
- Don't add Combine imports — this project uses @Observable + async/await
- Don't create "Manager" or "Coordinator" classes
- Don't put enums in Model/ — they go in Enum/

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
