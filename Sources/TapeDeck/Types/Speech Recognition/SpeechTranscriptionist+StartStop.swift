//
//  SpeechTranscriptionist+StartStop.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/14/24.
//

#if os(iOS)
import Suite
import AVFoundation
import Speech

extension SpeechTranscriptionist {
	public func start(textCallback: ((TranscriptionResult) -> Void)? = nil) async throws {
		self.textCallback = textCallback

		if isRunning { return }
		if Gestalt.isOnSimulator { throw Recorder.RecorderError.notImplementedOnSimulator }

		if await !TapeDeckPermissions.instance.requestRecordingPermissions() { throw Recorder.RecorderError.noPermissions }
		if await !TapeDeckPermissions.instance.requestTranscriptionPermission() { throw Recorder.RecorderError.noPermissions }

		self.fullTranscript = ""
		self.currentTranscription = SpeechTranscription()

		// The speech service needs an active, record-capable session. Standalone
		// transcription has no Recorder/Microphone to activate it, so do it here.
		try AVAudioSessionWrapper.instance.start()
		didActivateSession = true

		do {
			// Choose implementation based on iOS version
			if #available(iOS 26.0, *) {
				try await startWithSpeechAnalyzer()
			} else {
				try await startWithLegacyRecognizer()
			}
		} catch {
			try? AVAudioSessionWrapper.instance.stop()
			didActivateSession = false
			throw error
		}

		isRunning = true
		objectWillChange.send()
	}

	// iOS 15-18: Legacy SFSpeechRecognizer implementation
	private func startWithLegacyRecognizer() async throws {
		logg("Speech: using legacy SFSpeechRecognizer path (onDevice supported: \(self.speechRecognizer.supportsOnDeviceRecognition))")
		inputNode = audioEngine.inputNode

		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
		guard let recognitionRequest else { throw Recorder.RecorderError.unableToCreateRecognitionRequest }
		recognitionRequest.shouldReportPartialResults = true
		// Require on-device when supported: needed for offline use and to avoid the ~1 min
		// server-recognition limit on long recordings. Requires the system to have provisioned
		// the on-device model (enable Dictation for the language in Settings on iOS < 26).
		recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition

		guard let recordingFormat = inputNode?.outputFormat(forBus: 0) else { return }
		inputNode?.removeTap(onBus: 0)
		inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
			self.recognitionRequest?.append(buffer)
		}

		recognitionTask = buildRecognitionTask()

		if recognitionTask == nil {
			stop()
			throw Recorder.RecorderError.unableToCreateRecognitionTask
		}
		audioEngine.prepare()
		try audioEngine.start()
	}

	// iOS 26+: New SpeechAnalyzer implementation
	@available(iOS 26.0, *)
	private func startWithSpeechAnalyzer() async throws {
		// Create transcriber module
		guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
			throw Recorder.RecorderError.unsupportedLanguage
		}
		logg("Speech: using iOS 26 SpeechAnalyzer path")
		let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

		// Reserve + install the on-device model before analysis starts.
		try await ensureModel(for: transcriber, locale: locale)

		// Create input stream
		let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
		self.inputContinuation = continuation

		// Get optimal audio format
		guard let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
			throw Recorder.RecorderError.unableToCreateRecognitionRequest
		}

		// Create analyzer
		let analyzer = SpeechAnalyzer(modules: [transcriber])
		self.speechAnalyzer = analyzer

		// Set up audio tap with native format, then convert to required format
		inputNode = audioEngine.inputNode
		guard let nativeFormat = inputNode?.outputFormat(forBus: 0) else {
			throw Recorder.RecorderError.unableToCreateRecognitionRequest
		}

		// Create and store converter once (reused for all audio frames)
		guard let converter = AVAudioConverter(from: nativeFormat, to: audioFormat) else {
			throw Recorder.RecorderError.unableToCreateRecognitionRequest
		}
		self.audioConverter = converter

		// Capture continuation outside tap to avoid race condition
		guard let continuation = self.inputContinuation else {
			throw Recorder.RecorderError.unableToCreateRecognitionRequest
		}

		inputNode?.removeTap(onBus: 0)
		inputNode?.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { buffer, _ in
			// Reuse the converter created at setup time
			guard let converter = self.audioConverter else {
				logg("Audio converter not available")
				return
			}

			// Calculate frame capacity based on input buffer and conversion ratio
			let ratio = audioFormat.sampleRate / nativeFormat.sampleRate
			let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

			guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: outputFrameCapacity) else {
				logg("Failed to create converted audio buffer")
				return
			}

			var error: NSError?
			let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
				outStatus.pointee = .haveData
				return buffer
			}

			converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

			if let error {
				logg(error: error, "Audio conversion failed")
				return
			}

			// Yield directly - continuation.yield is Sendable and thread-safe
			let input = AnalyzerInput(buffer: convertedBuffer)
			continuation.yield(input)
		}

		audioEngine.prepare()
		try audioEngine.start()

		// Start processing results
		analysisTask = Task { @MainActor in
			await withTaskGroup(of: Void.self) { group in
				// Start analyzer in background
				group.addTask {
					do {
						let _ = try await analyzer.analyzeSequence(stream)
					} catch {
						logg(error: error, "Analyzer error")
					}
				}

				// Process transcription results
				group.addTask { @MainActor in
					do {
						for try await result in transcriber.results {
							let text = String(result.text.characters)

							// Update our transcription structure
							self.currentTranscription.updateFromFullTranscript(text, isFinal: result.isFinal)

							// Send callback with full transcript
							let fullText = self.currentTranscription.allText
							let confidence = result.isFinal ? 1.0 : 0.5
							self.textCallback?(.phrase(fullText, confidence))

							// Pause detection: restart timer on every result
							self.pauseTask?.cancel()
							self.pauseTask = Task {
								do {
									try await Task.sleep(for: .seconds(self.pauseDuration))
									self.textCallback?(.pause)
								} catch { }
							}
						}
					} catch {
						logg(error: error, "Speech analysis error")
					}
				}
			}
		}
	}
	
	public func stop() {
		currentTranscription.finalize()

		// Stop in correct order: tap → cleanup → engine
		// 1. Remove tap first to stop new audio samples
		inputNode?.removeTap(onBus: 0)

		// 2. Clean up based on which API was used
		if #available(iOS 26.0, *), speechAnalyzer != nil {
			stopSpeechAnalyzer()
		} else {
			stopLegacyRecognizer()
		}

		// 3. Stop audio engine last
		if isRunning {
			audioEngine.stop()
			isRunning = false
		}

		// 4. Release our hold on the audio session.
		if didActivateSession {
			try? AVAudioSessionWrapper.instance.stop()
			didActivateSession = false
		}

		inputNode = nil
		objectWillChange.send()
	}

	private func stopLegacyRecognizer() {
		recognitionRequest?.endAudio()
		recognitionRequest = nil
		recognitionTask?.cancel()
		recognitionTask = nil
	}

	@available(iOS 26.0, *)
	private func stopSpeechAnalyzer() {
		// End the input stream
		inputContinuation?.finish()
		inputContinuation = nil

		// Cancel analysis task and wait for completion
		analysisTask?.cancel()
		analysisTask = nil

		// Clean up audio converter
		audioConverter = nil

		// Clean up analyzer synchronously
		if let analyzer = speechAnalyzer {
			// Cancel and finish analyzer (fire-and-forget is acceptable here as cleanup)
			Task {
				await analyzer.cancelAndFinishNow()
			}
			speechAnalyzer = nil
		}
	}

}
#endif
