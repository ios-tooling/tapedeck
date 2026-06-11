//
//  RecordingSession.swift
//  TapeDeck
//
//	 The off-main-actor half of AudioRecorder: consumes captured buffers and
//	 feeds whichever writer is active, keeping file I/O off the main thread.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

actor RecordingSession {
	enum Output {
		case single(AudioFileWriter)
		case segmented(SegmentedWriter)
	}

	private var output: Output?
	private var isPaused = false
	private var lastLevelMark: TimeInterval = -1
	private(set) var lastError: Error?

	var duration: TimeInterval {
		switch output {
		case .single(let writer): writer.duration
		case .segmented(let writer): writer.duration
		case nil: 0
		}
	}

	func start(file url: URL, format: AudioFormat, input: AVAudioFormat) throws {
		output = .single(try AudioFileWriter(url: url, format: format, input: input))
	}

	func start(package: RecordingPackage, format: AudioFormat, chunkDuration: TimeInterval, ringDuration: TimeInterval?, input: AVAudioFormat) throws {
		output = .segmented(try SegmentedWriter(package: package, format: format, chunkDuration: chunkDuration, ringDuration: ringDuration, input: input))
	}

	func setPaused(_ paused: Bool) {
		isPaused = paused
	}

	// returns the new duration once written, nil if the buffer was skipped
	func handle(_ captured: CapturedAudio) -> TimeInterval? {
		guard !isPaused, let output else { return nil }

		do {
			switch output {
			case .single(let writer):
				try writer.write(captured.buffer)

			case .segmented(let writer):
				try writer.write(captured.buffer)
				if writer.duration - lastLevelMark >= 1 {
					writer.recordLevel(captured.level)
					lastLevelMark = writer.duration
				}
			}
		} catch {
			if lastError == nil { lastError = error }
			return nil
		}
		return duration
	}

	func handleFormatChange(_ format: AVAudioFormat) {
		switch output {
		case .single(let writer): writer.updateInputFormat(format)
		case .segmented(let writer): writer.updateInputFormat(format)
		case nil: break
		}
	}

	func finish() throws -> Recording {
		defer { output = nil }
		if let lastError { throw lastError }

		switch output {
		case .single(let writer): return .file(try writer.finish())
		case .segmented(let writer): return .package(try writer.finish())
		case nil: throw TapeDeckError.notRecording
		}
	}
}
