# TapeDeck v2 Rebuild Plan

## Context

TapeDeck v1 grew into a tangle of independent audio subsystems (AVCaptureSession recorder, /dev/null-metering Microphone, standalone transcription engine) coordinated by listener stacks. Ben is rebuilding from scratch on the `v2` branch: a broad, simple, flexible wrapper around **audio recording, file playback, and speech-to-text**, targeting iOS 18+ with a distinct iOS 26 transcription path (SpeechAnalyzer). A skeleton API exists in `Sources/TapeDeck/`; Snoreganization (`/Users/ben/Documents/ManagedProjects/iPhone Dev/Snoreganization`) provides proven visualization code to port.

## Decisions (locked via interview)

1. **Shared pipeline**: one internal AVAudioEngine input tap fans buffers out to recorder, level meter, and transcriber — any combination runs concurrently.
2. **Public singletons**: `AudioRecorder.instance`, `Microphone.instance`, `Transcriber.instance`, `AudioPlayer.instance`, `RecordingStore.instance`. All `@MainActor @Observable`.
3. **Recording modes**: single-file + segmented (chunked folder) with optional ring buffer (keep last N minutes). No raw-PCM writer, no pluggable output protocol.
4. **Formats**: m4a (AAC, configurable bitrate) and wav (configurable sample rate). Segmented recordings are a **package folder** (chunks + JSON manifest: levels summary, optional transcript, timestamps).
5. **Playback**: `AudioPlayer` singleton wrapping AVPlayer/AVQueuePlayer; plays single `AudioFile`s and packages (queued seamlessly).
6. **Transcription**: both live-mic streaming and file transcription (`transcribe(file:) async throws -> TranscribedConversation`).
7. **Rename** `SpeechTranscriber` → **`Transcriber`** (avoids collision with Apple's iOS 26 `Speech.SpeechTranscriber`).
8. **Utterance model**: `{ text, timeRange, confidence, speaker: String? }` — speaker always nil from Apple engines; field is future-proofing.
9. **AmbientSoundView styles**: all four — Siri-like wave, LED matrix, segmented bar, analog VU needle.
10. **WaveFormView**: full zoom/scrub — pinch-zoom, pan, playhead, tap-to-seek (port Snoreganization's chart stack).
11. **RecordingStore included**: observable directory-rooted library with delete.
12. **Platforms**: iOS 18+ and macOS 15+ only. Drop watchOS. `AVAudioSession` code behind `#if os(iOS)`.
13. **Interruptions**: always auto-pause; `resumesAfterInterruption` (default `false`) opt-in auto-resume. State observable so apps can show "paused by interruption".
14. **Live results delivery**: observable state (tentative/finalized text, conversation-so-far) **plus** `AsyncStream<Utterance>` for event-driven consumers.

Judgment calls (consistent with the above): runtime backend selection via `if #available(iOS 26, macOS 26, *)`; permissions auto-requested on start with explicit async request methods also exposed; Chronicle for logging; Swift Testing; files ≤ ~100 lines, split by functionality.

## Architecture

```
                    ┌─ AudioRecorder ── SingleFileWriter / SegmentedWriter ─→ files/package
AudioSource (actor) ─┼─ Microphone ──── LevelHistory ─→ AmbientSoundView
 owns AVAudioEngine  └─ Transcriber ─── TranscriptionBackend (18 vs 26) ─→ TranscribedConversation
                                                              ↑ also reads AudioFile directly
AudioPlayer ── AVPlayer/AVQueuePlayer ─→ plays AudioFile / RecordingPackage
RecordingStore ── scans root dir ─→ [AudioFile/RecordingPackage]
```

- **`AudioSource`** (internal actor): owns the single `AVAudioEngine` + input tap. Subscribers get an `AsyncStream<AVAudioPCMBuffer>`. Engine starts on first subscriber, stops on last unsubscribe. Handles `#if os(iOS)` AVAudioSession config (`.playAndRecord`, bluetooth options — port v1's `AVAudioSessionWrapper` option set), interruption + route-change notifications, and publishes interruption events to subscribers.
- **Levels math**: per-buffer RMS → dB → normalized 0–1 against a calibratable noise floor (port Snoreganization's `SoundLevelCalibration`, default −80 dB; v1 used a 90 dB offset — use the Snoreganization approach, it's cleaner and AGC-aware).
- **Transcription backends**: internal protocol with two implementations — `SFSpeechBackend` (iOS 18–25 / macOS 15–25: `SFSpeechRecognizer`, live via buffer feed, file via `SFSpeechURLRecognitionRequest`) and `AnalyzerBackend` (iOS/macOS 26+: `SpeechAnalyzer` + `Speech.SpeechTranscriber`, including `AssetInventory` model download, `bestAvailableAudioFormat` conversion via `AVAudioConverter`). v1's iOS 26 code on the `swift-6` branch (`git show swift-6:…SpeechTranscriptionist…`) is the reference for the analyzer pipeline.

## Public API surface (target)

```swift
// AudioRecorder.instance
func record(to url: URL, format: AudioFormat) async throws            // single file
func record(packageAt url: URL, format: AudioFormat,
            chunkDuration: TimeInterval, ringDuration: TimeInterval?) async throws
func pause() / func resume() async throws / func stop() async throws -> AudioFile
var state: State            // idle, recording, paused(byInterruption: Bool), finishing
var duration: TimeInterval, currentLevel: AudioLevel
var resumesAfterInterruption = false

// Microphone.instance
func start() async throws / func stop()
var currentLevel: AudioLevel        // dB + normalized
var history: LevelHistory           // rolling timestamped samples; recent(_:), data(inLast:), average(over:)

// Transcriber.instance
func start() async throws / func stop() async
var tentativeText: String, finalizedText: String, conversation: TranscribedConversation
var utterances: AsyncStream<Utterance>
func transcribe(file: AudioFile, locale: Locale = .current) async throws -> TranscribedConversation

// AudioPlayer.instance
func play(_ file: AudioFile) / func play(_ package: RecordingPackage)
func pause() / func resume() / func stop() / func seek(to: TimeInterval)
var isPlaying: Bool, progress: Double, currentTime/duration: TimeInterval

// RecordingStore.instance
func setup(root: URL) / var recordings: [Recording] / func delete(_:)

// Permissions
static func requestMicrophone() async -> Bool
static func requestSpeechRecognition() async -> Bool
```

Models: `AudioFile` (url, async duration/format metadata), `TranscribedConversation { utterances: [Utterance] }` (Codable), `Utterance { text, timeRange: Range<TimeInterval>, confidence: Double, speaker: String?, isFinal }`, `RecordingPackage` (folder + `manifest.json` with chunk list, level summary, optional transcript), `AudioFormat` (.m4a(bitrate:), .wav(sampleRate:)), `AudioLevel` (dB + normalized).

Views: `RecordButton` (drives AudioRecorder; start from v1's recently-tweaked `TapeDeckRecordButton` on `swift-6`), `AmbientSoundView(style:)` with `.siriWave`, `.ledMatrix`, `.bar`, `.analogVU` (port Snoreganization's `WaveformCanvasMeter`, `StereoLEDMeter`, `HorizontalBarMeter`; build VU needle fresh with Canvas), `WaveFormView(file:)` with pinch-zoom/pan/playhead/tap-to-seek (port `WaveformExtractor` peak-envelope + cache, `ChartWindow` zoom math, `WaveformDetailTrack`, `TimelineMinimap`), `TranscribedTextField` (renders finalizedText solid + tentativeText dimmed).

## File layout (Sources/TapeDeck/)

`Core/` AudioSource.swift, AudioSession.swift (#if os(iOS)), Permissions.swift, AudioLevel.swift, TapeDeckError.swift · `Classes/` AudioRecorder.swift (+AudioRecorder+Writers.swift), Microphone.swift, LevelHistory.swift, Transcriber.swift, Transcriber+SFSpeech.swift, Transcriber+Analyzer.swift, AudioPlayer.swift, RecordingStore.swift · `Model/` AudioFile.swift, TranscribedConversation.swift, Utterance.swift, RecordingPackage.swift, AudioFormat.swift · `Views/` RecordButton.swift, AmbientSoundView.swift + one file per meter style, WaveFormView.swift + WaveformExtractor.swift + ChartWindow.swift + subviews, TranscribedTextField.swift

Note: git status shows stale duplicate stubs at `Sources/TapeDeck/` root (`AudioFile.swift`, `Microphone.swift`, etc. marked AD); reconcile so each type lives in one place per the layout above.

## Implementation order

1. **Core**: TapeDeckError, AudioLevel, Permissions, AudioSession wrapper, AudioSource actor with fan-out streams + interruption handling. (Unit-test levels math.)
2. **Microphone**: levels + LevelHistory off the shared source.
3. **AudioRecorder**: single-file (AVAudioFile writing from buffers; m4a via AVAudioFile AAC settings, wav via converter), then segmented writer + chunk rotation (`<index>.<start>-<duration>.<ext>` naming from v1) + ring-buffer pruning + manifest. Pause/resume/interruptions.
4. **AudioPlayer**: single file, then queued package playback with progress.
5. **Models**: TranscribedConversation/Utterance Codable round-trip tests; RecordingPackage manifest read/write tests.
6. **Transcriber**: backend protocol; SFSpeech backend (live + file); Analyzer backend (26+, reference v1's swift-6 implementation); observable state + AsyncStream.
7. **Views**: RecordButton → AmbientSoundView styles → WaveFormView stack → TranscribedTextField.
8. **RecordingStore**: scan, observe, delete.

## Verification

- `swift build` for iOS and macOS destinations; `swift test` (Swift Testing) for: levels math (RMS→dB→normalized), chunk filename parse/format, ring-buffer pruning logic, manifest + TranscribedConversation Codable round-trips, ChartWindow zoom math.
- Live-mic features (record, levels, live transcription, interruptions) need a device: smoke-test via a minimal demo app or the existing TapeDeck scheme on-device — record single + segmented, play back, live-transcribe on an iOS 18 device and an iOS 26 device/simulator if available.
- File transcription is testable in CI-ish conditions with a bundled fixture audio file (SFSpeechRecognizer requires entitlements/network — keep as on-device manual check if flaky).
