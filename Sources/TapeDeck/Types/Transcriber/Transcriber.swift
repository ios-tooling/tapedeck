//
//  Transcriber.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 7/7/25.
//

import Suite
import Speech

@Observable @MainActor class Transcriber: TranscriptionProviding {
	private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
	private var inputSequence: AsyncStream<AnalyzerInput>?
	private var recorder: AudioRecorder = AudioRecorder()
	private var transcriber: SpeechTranscriber?
	private var analyzer: SpeechAnalyzer?
	private var locale = Locale.current
	private var analyzerFormat: AVAudioFormat?
	var modelDownloadProgress: Progress?
	var converter = AudioBufferConverter()
	private var recognizerTask: Task<(), Error>?
	var pendingTranscript: AttributedString = ""
	var finalizedTranscript: AttributedString = ""
	
	init() {
	}
	
	enum TranscriberError: String, Throwable { case inputNotConfigured, wrongFormat, noTranscriber, localeNotSupported, noInputSequence }
	
	func setup() async throws {
		if transcriber != nil { return } 		// already setup
		
		transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [.audioTimeRange])
		
		guard let transcriber else { throw TranscriberError.noTranscriber }
		
		analyzer = SpeechAnalyzer(modules: [transcriber])
		
		do {
			try await ensureModel(transcriber: transcriber, locale: Locale.current)
		} catch {
			throw error
		}
		
		self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
		(inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
	}
}

extension Transcriber: Recordable {
	var state: RecordableState { recorder.state }
	
	func record() async throws {
		try await setup()

		guard let transcriber else { throw TranscriberError.noTranscriber }
		guard let inputSequence else { throw TranscriberError.noInputSequence }
		
		recognizerTask = Task {
			do {
				for try await case let result in transcriber.results {
					let text = result.text
					if result.isFinal {
						finalizedTranscript += text
						pendingTranscript = ""
					} else {
						pendingTranscript = text
						pendingTranscript.foregroundColor = .red.opacity(0.5)
					}
				}
			} catch {
				print("speech recognition failed")
			}
		}

		Task {
			do {
				try await recorder.start { [self] buffer in
					guard let inputBuilder else { throw TranscriberError.inputNotConfigured }
					guard let analyzerFormat else { throw TranscriberError.wrongFormat }
					
					let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
					let input = AnalyzerInput(buffer: converted)
					
					inputBuilder.yield(input)
				}
			} catch {
				print("Recording failed: \(error)")
			}
		}
		
		try await analyzer?.start(inputSequence: inputSequence)
	}
	
	func pause() {
		recorder.pause()
	}
	
	func resume() throws {
		try recorder.resume()
	}
	
	func stop() async {
		await finishTranscribing()
		recorder.stop()
	}
	
	func finishTranscribing() async {
		do {
			inputBuilder?.finish()
			try await analyzer?.finalizeAndFinishThroughEndOfInput()
			recognizerTask?.cancel()
			recognizerTask = nil
			analyzer = nil
			transcriber = nil
		} catch {
			print("Failed to finish transcribing: \(error)")
		}
	}

	
	
}
