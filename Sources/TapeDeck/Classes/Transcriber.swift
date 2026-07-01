//
//  Transcriber.swift
//  TapeDeck
//
//	 Speech-to-text off the shared mic pipeline (live) or from audio files.
//	 Uses SpeechAnalyzer on iOS/macOS 26+, SFSpeechRecognizer on earlier OSes.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation

@MainActor @Observable public class Transcriber {
	public static let instance = Transcriber()

	public private(set) var isTranscribing = false
	public private(set) var conversation = TranscribedConversation()
	public var locale = Locale.current

	// Live input level off the shared mic tap, and a derived speech/silence flag.
	// Updated while transcribing; consumers can use these for VAD-style pause detection.
	public private(set) var inputLevel: AudioLevel = .silent
	public private(set) var isSpeaking = false
	/// Average (RMS) dBFS at or above which input counts as speech (≤ 0). Tune per environment.
	public var speechThreshold: Double = -40

	public var finalizedText: String { conversation.finalizedText }
	public var tentativeText: String { conversation.tentativeText }

	private var backend: (any TranscriptionBackend)?
	private var subscription: AudioSubscription?
	private var pumpTask: Task<Void, Never>?
	private let utteranceRelay = StreamRegistry<Utterance>()

	// every finalized utterance, as it arrives; for await in as many places as you like
	public func utterances() -> AsyncStream<Utterance> {
		utteranceRelay.makeStream()
	}

	public func clear() {
		conversation = TranscribedConversation()
	}

	public func start() async throws {
		guard !isTranscribing else { return }
		guard await TapeDeckPermissions.instance.requestSpeechRecognition() else { throw TapeDeckError.speechRecognitionPermissionDenied }

		let subscription = try await AudioSource.instance.subscribe()
		guard let format = subscription.format else { throw TapeDeckError.audioEngineUnavailable }

		let backend = Self.makeBackend()
		do {
			try await backend.startLive(format: format, locale: locale) { [weak self] update in self?.apply(update) }
		} catch {
			subscription.cancel()
			throw error
		}

		self.subscription = subscription
		self.backend = backend
		isTranscribing = true

		pumpTask = Task {
			for await event in subscription.events {
				switch event {
				case .audio(let captured):
					backend.feed(captured)
					updateActivity(captured.level)
				case .formatChanged(let format): backend.inputFormatChanged(to: format)
				case .interruptionBegan, .interruptionEnded: break
				}
			}
		}
	}

	public func stop() async {
		guard isTranscribing else { return }

		subscription?.cancel()
		subscription = nil
		await pumpTask?.value
		pumpTask = nil
		await backend?.stopLive()
		backend = nil
		isTranscribing = false
		inputLevel = .silent
		isSpeaking = false

		// anything still tentative when we stop is as final as it will ever get
		if let last = conversation.utterances.last(where: { !$0.isFinal }) {
			apply(.finalized(Utterance(text: last.text, confidence: last.confidence, isFinal: true)))
		}
	}

	public func transcribe(file: AudioFile, locale: Locale = .current) async throws -> TranscribedConversation {
		guard file.exists else { throw TapeDeckError.fileNotFound(file.url) }
		guard await TapeDeckPermissions.instance.requestSpeechRecognition() else { throw TapeDeckError.speechRecognitionPermissionDenied }

		return try await Self.makeBackend().transcribe(url: file.url, locale: locale)
	}

	private func updateActivity(_ level: AudioLevel) {
		inputLevel = level
		isSpeaking = level.decibels >= speechThreshold
	}

	private func apply(_ update: TranscriptionUpdate) {
		switch update {
		case .tentative(let text):
			conversation.replaceTentative(with: text.isEmpty ? nil : Utterance(text: text))

		case .finalized(let utterance):
			conversation.replaceTentative(with: nil)
			conversation.append(utterance)
			utteranceRelay.yield(utterance)
		}
	}

	private static func makeBackend() -> any TranscriptionBackend {
		if #available(iOS 26.0, macOS 26.0, *) {
			AnalyzerBackend()
		} else {
			SFSpeechBackend()
		}
	}
}

enum TranscriptionUpdate: Sendable {
	case tentative(String)
	case finalized(Utterance)
}

@MainActor protocol TranscriptionBackend: AnyObject {
	func startLive(format: AVAudioFormat, locale: Locale, onUpdate: @escaping @MainActor (TranscriptionUpdate) -> Void) async throws
	func feed(_ captured: CapturedAudio)
	func inputFormatChanged(to format: AVAudioFormat)
	func stopLive() async
	func transcribe(url: URL, locale: Locale) async throws -> TranscribedConversation
}
