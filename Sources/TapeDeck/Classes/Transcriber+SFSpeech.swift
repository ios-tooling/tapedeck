//
//  Transcriber+SFSpeech.swift
//  TapeDeck
//
//	 SFSpeechRecognizer-based transcription for iOS 18–25 / macOS 15–25. Live
//	 recognition restarts its request after each finalized result, since the
//	 system ends recognition tasks after roughly a minute.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation
import Speech

@MainActor final class SFSpeechBackend: TranscriptionBackend {
	private var recognizer: SFSpeechRecognizer?
	private var request: SFSpeechAudioBufferRecognitionRequest?
	private var task: SFSpeechRecognitionTask?
	private var onUpdate: (@MainActor (TranscriptionUpdate) -> Void)?

	func startLive(format: AVAudioFormat, locale: Locale, onUpdate: @escaping @MainActor (TranscriptionUpdate) -> Void) async throws {
		let recognizer = try Self.recognizer(for: locale)
		self.recognizer = recognizer
		self.onUpdate = onUpdate
		buildRequest()
	}

	func feed(_ captured: CapturedAudio) {
		request?.append(captured.buffer)
	}

	func inputFormatChanged(to format: AVAudioFormat) { }		// append() accepts per-buffer formats

	func stopLive() async {
		request?.endAudio()
		task?.cancel()
		request = nil
		task = nil
		onUpdate = nil
		recognizer = nil
	}

	func transcribe(url: URL, locale: Locale) async throws -> TranscribedConversation {
		let recognizer = try Self.recognizer(for: locale)
		let request = SFSpeechURLRecognitionRequest(url: url)
		request.shouldReportPartialResults = false
		request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

		return try await withCheckedThrowingContinuation { continuation in
			let guarded = ResumeGuard(continuation)
			recognizer.recognitionTask(with: request) { result, error in
				if let error {
					guarded.resume(throwing: error)
				} else if let result, result.isFinal {
					guarded.resume(returning: TranscribedConversation(utterances: [Self.utterance(from: result)]))
				}
			}
		}
	}

	private static func recognizer(for locale: Locale) throws -> SFSpeechRecognizer {
		guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
			throw TapeDeckError.transcriptionUnavailable
		}
		recognizer.queue = .main
		return recognizer
	}

	private func buildRequest() {
		guard let recognizer else { return }

		let request = SFSpeechAudioBufferRecognitionRequest()
		request.shouldReportPartialResults = true
		request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
		self.request = request

		task = recognizer.recognitionTask(with: request) { [weak self] result, error in
			MainActor.assumeIsolated { self?.handle(result: result, error: error) }
		}
	}

	private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
		guard request != nil else { return }									// already stopped

		if let error {
			let ns = error as NSError
			if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 { return }	// no speech detected
			buildRequest()																		// recover and keep listening
			return
		}

		guard let result else { return }
		if result.isFinal {
			onUpdate?(.finalized(Self.utterance(from: result)))
			buildRequest()																		// recognition tasks time out; chain a fresh one
		} else {
			onUpdate?(.tentative(result.bestTranscription.formattedString))
		}
	}

	private static func utterance(from result: SFSpeechRecognitionResult) -> Utterance {
		let segments = result.bestTranscription.segments
		let confidence = segments.isEmpty ? 0 : segments.map { Double($0.confidence) }.reduce(0, +) / Double(segments.count)
		var timeRange: Range<TimeInterval>?

		if let first = segments.first, let last = segments.last, last.timestamp + last.duration > first.timestamp {
			timeRange = first.timestamp..<(last.timestamp + last.duration)
		}
		return Utterance(text: result.bestTranscription.formattedString, timeRange: timeRange, confidence: confidence, isFinal: true)
	}
}

// SFSpeechRecognizer can call back with an error even after delivering a result
private final class ResumeGuard<T: Sendable>: @unchecked Sendable {
	private let lock = NSLock()
	private var continuation: CheckedContinuation<T, Error>?

	init(_ continuation: CheckedContinuation<T, Error>) {
		self.continuation = continuation
	}

	func resume(returning value: T) {
		take()?.resume(returning: value)
	}

	func resume(throwing error: Error) {
		take()?.resume(throwing: error)
	}

	private func take() -> CheckedContinuation<T, Error>? {
		lock.withLock {
			defer { continuation = nil }
			return continuation
		}
	}
}
