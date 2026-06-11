//
//  Transcriber+Analyzer.swift
//  TapeDeck
//
//	 SpeechAnalyzer-based transcription for iOS/macOS 26+. Volatile results feed
//	 tentative text; finalized results become utterances.
//
//  Created by Ben Gottlieb on 6/11/26.
//

@preconcurrency import AVFoundation
import Speech

@available(iOS 26.0, macOS 26.0, *)
@MainActor final class AnalyzerBackend: TranscriptionBackend {
	private var analyzer: SpeechAnalyzer?
	private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
	private var converter: AVAudioConverter?
	private var analyzerFormat: AVAudioFormat?
	private var analysisTask: Task<Void, Never>?
	private var resultsTask: Task<Void, Never>?

	func startLive(format: AVAudioFormat, locale: Locale, onUpdate: @escaping @MainActor (TranscriptionUpdate) -> Void) async throws {
		let transcriber = try await Self.makeTranscriber(locale: locale)

		guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
			throw TapeDeckError.transcriptionUnavailable
		}
		self.analyzerFormat = analyzerFormat
		inputFormatChanged(to: format)

		let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
		inputContinuation = continuation

		let analyzer = SpeechAnalyzer(modules: [transcriber])
		self.analyzer = analyzer

		analysisTask = Task {
			_ = try? await analyzer.analyzeSequence(stream)
		}
		resultsTask = Task { @MainActor in
			await Self.relayResults(from: transcriber, to: onUpdate)
		}
	}

	func feed(_ captured: CapturedAudio) {
		guard let analyzerFormat, let inputContinuation else { return }

		let buffer = captured.buffer
		guard let converter else {
			inputContinuation.yield(AnalyzerInput(buffer: buffer))
			return
		}
		let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
		let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
		guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }

		var consumed = false
		var error: NSError?
		let status = converter.convert(to: converted, error: &error) { _, inputStatus in
			if consumed {
				inputStatus.pointee = .noDataNow
				return nil
			}
			consumed = true
			inputStatus.pointee = .haveData
			return buffer
		}

		guard status != .error, converted.frameLength > 0 else { return }
		inputContinuation.yield(AnalyzerInput(buffer: converted))
	}

	func inputFormatChanged(to format: AVAudioFormat) {
		guard let analyzerFormat else { return }
		converter = format == analyzerFormat ? nil : AVAudioConverter(from: format, to: analyzerFormat)
	}

	func stopLive() async {
		inputContinuation?.finish()
		inputContinuation = nil

		if let analyzer {
			try? await analyzer.finalizeAndFinishThroughEndOfInput()
		}
		await resultsTask?.value
		analysisTask = nil
		resultsTask = nil
		analyzer = nil
		converter = nil
	}

	func transcribe(url: URL, locale: Locale) async throws -> TranscribedConversation {
		let transcriber = try await Self.makeTranscriber(locale: locale)
		let analyzer = SpeechAnalyzer(modules: [transcriber])
		let file = try AVAudioFile(forReading: url)

		var conversation = TranscribedConversation()
		let collector = Task { @MainActor in
			await Self.relayResults(from: transcriber) { update in
				if case .finalized(let utterance) = update { conversation.append(utterance) }
			}
		}

		if let lastSample = try await analyzer.analyzeSequence(from: file) {
			try await analyzer.finalizeAndFinish(through: lastSample)
		} else {
			await analyzer.cancelAndFinishNow()
		}

		await collector.value
		return conversation
	}

	private static func makeTranscriber(locale: Locale) async throws -> SpeechTranscriber {
		guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
			throw TapeDeckError.transcriptionUnavailable
		}

		let transcriber = SpeechTranscriber(locale: supported, preset: .progressiveTranscription)

		do {
			if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
				try await request.downloadAndInstall()
			}
		} catch {
			throw TapeDeckError.transcriptionAssetsUnavailable
		}
		return transcriber
	}

	private static func relayResults(from transcriber: SpeechTranscriber, to onUpdate: @MainActor (TranscriptionUpdate) -> Void) async {
		do {
			for try await result in transcriber.results {
				let text = String(result.text.characters)
				if result.isFinal {
					onUpdate(.finalized(Utterance(text: text, confidence: 1, isFinal: true)))
				} else {
					onUpdate(.tentative(text))
				}
			}
		} catch { }
	}
}
