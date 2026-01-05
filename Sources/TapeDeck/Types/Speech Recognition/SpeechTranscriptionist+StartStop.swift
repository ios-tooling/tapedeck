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
	@MainActor public func start(textCallback: ((TranscriptionResult) -> Void)? = nil) async throws {
		self.textCallback = textCallback

		if isRunning { return }
		if Gestalt.isOnSimulator { throw Recorder.RecorderError.notImplementedOnSimulator }

		if await !requestPermission() { throw Recorder.RecorderError.noPermissions }

		self.fullTranscript = ""
		self.currentTranscription = SpeechTranscription()

		// Choose implementation based on iOS version
		if #available(iOS 26.0, *) {
			try await startWithSpeechAnalyzer()
		} else {
			try await startWithLegacyRecognizer()
		}

		isRunning = true
		objectWillChange.send()
	}

	// iOS 15-25: Legacy SFSpeechRecognizer implementation
	@MainActor private func startWithLegacyRecognizer() async throws {
		inputNode = audioEngine.inputNode

		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
		guard let recognitionRequest else { throw Recorder.RecorderError.unableToCreateRecognitionRequest }
		recognitionRequest.shouldReportPartialResults = true
		recognitionRequest.requiresOnDeviceRecognition = true

		guard let recordingFormat = inputNode?.outputFormat(forBus: 0) else { return }
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
	@MainActor private func startWithSpeechAnalyzer() async throws {
		// Create transcriber module
		guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
			throw Recorder.RecorderError.noPermissions
		}
		let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

		// Check and install required assets
		if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
			try await request.downloadAndInstall()
		}

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
		guard let nativeFormat = inputNode?.outputFormat(forBus: 0) else { return }

		// Create audio converter
		guard let converter = AVAudioConverter(from: nativeFormat, to: audioFormat) else {
			throw Recorder.RecorderError.unableToCreateRecognitionRequest
		}

		inputNode?.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, _ in
			guard let self else { return }

			// Convert buffer to required format
			guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioFormat.sampleRate * 0.1)) else { return }

			var error: NSError?
			let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
				outStatus.pointee = .haveData
				return buffer
			}

			converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

			if error == nil {
				// Yield converted buffer to analyzer input stream
				let input = AnalyzerInput(buffer: convertedBuffer)
				Task { @MainActor in
					self.inputContinuation?.yield(input)
				}
			}
		}

		audioEngine.prepare()
		try audioEngine.start()

		// Start processing results
		analysisTask = Task { @MainActor in
			do {
				// Start analysis concurrently with results processing
				async let _ = analyzer.analyzeSequence(stream)

				// Process transcription results
				for try await result in transcriber.results {
					let text = String(result.text.characters)

					// Update our transcription structure with full transcript
					self.currentTranscription.updateFromFullTranscript(text, isFinal: result.isFinal)

					// Update callback with new text
					if text.hasPrefix(self.lastString) {
						self.fullTranscript += text.dropFirst(self.lastString.count) + " "
					} else {
						self.fullTranscript = text + " "
					}
					self.lastString = text
					self.textCallback?(.phrase(text, 1.0))
				}
			} catch {
				logg(error: error, "Speech analysis error")
			}
		}
	}
	
	@MainActor public func stop() {
		currentTranscription.finalize()

		if isRunning {
			audioEngine.stop()
			isRunning = false
		}

		inputNode?.removeTap(onBus: 0)

		// Clean up based on which API was used
		if #available(iOS 26.0, *), speechAnalyzer != nil {
			stopSpeechAnalyzer()
		} else {
			stopLegacyRecognizer()
		}

		inputNode = nil
		objectWillChange.send()
	}

	@MainActor private func stopLegacyRecognizer() {
		recognitionRequest?.endAudio()
		recognitionRequest = nil
		recognitionTask?.cancel()
		recognitionTask = nil
	}

	@available(iOS 26.0, *)
	@MainActor private func stopSpeechAnalyzer() {
		// End the input stream
		inputContinuation?.finish()
		inputContinuation = nil

		// Cancel analysis task
		analysisTask?.cancel()
		analysisTask = nil

		// Clean up analyzer
		if let analyzer = speechAnalyzer {
			Task {
				try? await analyzer.cancelAndFinishNow()
			}
		}
		speechAnalyzer = nil
	}

}
#endif
