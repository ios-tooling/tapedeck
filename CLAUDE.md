# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TapeDeck is an iOS audio recording and transcription framework built with Swift. It provides high-level abstractions for audio capture, live monitoring, segmented/continuous recording, format conversion, and speech-to-text transcription using Apple's Speech Recognition framework.

**Platform Support**: iOS only (iOS 15+). All code is conditionally compiled with `#if os(iOS)`.

**Dependencies**:
- Suite (https://github.com/ios-tooling/Suite.git)
- Journalist (https://github.com/ios-tooling/Journalist.git)

## Build & Test Commands

```bash
# Build the framework
swift build

# Run tests
swift test

# Build the demo app (TapeDeckHarness)
# Open TapeDeckHarness/TapeDeckHarness.xcodeproj in Xcode and build
```

**Note**: Most functionality requires a physical iOS device as recording is not supported on the simulator. Code will throw `RecorderError.cantRecordOnSimulator` when run on simulators.

## Architecture

### Core Components

The framework is organized around several key singleton actors and classes that manage different aspects of audio recording:

**Microphone** (`Sources/TapeDeck/Types/Microphone/Microphone.swift`)
- Singleton (`Microphone.instance`) that provides ambient audio level monitoring
- Uses AVAudioRecorder pointed at `/dev/null` for metering only
- Tracks volume history and publishes updates via Combine
- Manages a listener stack to coordinate multiple recording requests
- Does NOT write audio data - only monitors levels

**Recorder** (`Sources/TapeDeck/Types/Recorder/Recorder.swift`)
- Main recording engine, singleton (`Recorder.instance`)
- Uses AVCaptureSession with AVCaptureAudioDataOutput for actual audio capture
- Handles audio sample buffers via `AVCaptureAudioDataOutputSampleBufferDelegate`
- Manages recording state (idle, running, paused, post)
- Coordinates with RecorderOutput implementations to write data
- Supports optional live transcription during recording

**RecorderOutput Protocol** (`Sources/TapeDeck/Types/Recorder/RecorderOutput.swift`)
- Defines how audio samples are handled/stored
- Key implementations:
  - `OutputSingleFileRecording`: Records to a single continuous file
  - `OutputSegmentedRecording`: Splits recording into time-based chunks (ring buffer support)
  - `OutputDevNull`: Discards samples (used for level monitoring only)

**RecordingStore** (`Sources/TapeDeck/Types/Recording Store/RecordingStore.swift`)
- Singleton (`RecordingStore.instance`) that manages saved recordings
- Scans filesystem for audio files and maintains recording catalog
- Publishes changes to recordings list
- Supports multiple directory sources

**SavedRecording** (`Sources/TapeDeck/Types/Saved Recording/SavedRecording.swift`)
- Represents a recorded audio file
- Handles playback state and progress
- Can represent both single files and recording packages (.tdpkg)

### Audio Conversion Pipeline

**AudioFileConverter** (`Sources/TapeDeck/Types/AudioConverter/AudioFileConverter.swift`)
- Converts between audio formats (WAV, M4A, MP3)
- Used by RecorderOutputs to convert internal format to desired output format
- Internal recordings typically use 48kHz WAV, then convert to output format (16kHz WAV, M4A, etc.)

### Transcription System

**SpeechTranscriptionist** (`Sources/TapeDeck/Types/Speech Recognition/SpeechTranscriptionist.swift`)
- Singleton for live speech-to-text using Apple's Speech framework
- Requires microphone permissions
- Provides real-time transcription with confidence scores

**Transcript** (`Sources/TapeDeck/Types/Recorder/Transcript.swift`)
- Manages transcription metadata for recordings
- Stores segment timing and transcribed text
- Persists alongside audio files

### Actor Isolation

The codebase uses Swift's actor isolation model:
- `@MainActor` classes: `Microphone`, `Recorder`, `RecordingStore`, `SpeechTranscriptionist`
- Custom global actors: `@AudioActor` for audio processing
- RecorderOutput implementations are `actor` types for thread-safe sample handling

### Listener Stack Pattern

Microphone and Recorder use a listener stack to coordinate multiple recording requests:
- `setActive(_:)` pushes the current active listener and activates a new one
- `clearActive(_:)` pops the stack and resumes previous listener
- This allows nested recording contexts (e.g., Recorder requesting Microphone while another component is also listening)

## Key File Types

- `.tdpkg`: Recording package (directory with metadata and audio chunks)
- `.m4a`, `.wav`, `.mp3`: Standard audio formats
- `.raw`: Raw PCM sample data (used internally by segmented recording)

## Common Patterns

**Starting a recording:**
```swift
let output = OutputSingleFileRecording(url: destinationURL, type: .m4a)
try await Recorder.instance.startRecording(to: output, shouldTranscribe: true)
```

**Stopping a recording:**
```swift
try await Recorder.instance.stop()
```

**Monitoring ambient levels:**
```swift
try await Microphone.instance.start()
// Access levels via Microphone.instance.history
```

**Segmented recording with ring buffer:**
```swift
let output = OutputSegmentedRecording(
    in: packageURL,
    outputType: .wav16k,
    bufferDuration: 30,
    ringDuration: 300 // 5 minutes rolling buffer
)
```

## Test Structure

Tests are minimal (see `Tests/TapeDeckTests/TapeDeckTests.swift`). The framework is primarily tested via the TapeDeckHarness demo app.

## Demo App

**TapeDeckHarness** is an iOS app demonstrating the framework:
- Located in `TapeDeckHarness/`
- Entry point: `TapeDeckHarnessApp.swift`
- Main view: `LongTermRecordingView.swift`
- Shows recording UI, playback, and file management

## Important Notes

- All recording functionality requires iOS device - simulator will throw errors
- Audio session management is handled via `AVAudioSessionWrapper`
- Interruption handling is built-in (phone calls, etc.) but some interruption code is commented out
- The framework uses `#if os(iOS)` throughout - all code is iOS-specific
