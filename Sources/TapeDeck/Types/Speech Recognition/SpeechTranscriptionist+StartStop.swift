//
//  SpeechTranscriptionist+StartStop.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 10/14/24.
//

import Suite
import AVFoundation
import Speech

extension SpeechTranscriptionist {
	@MainActor public func start(textCallback: ((TranscriptionResult) -> Void)? = nil) async throws {
		self.textCallback = textCallback

		if isRunning { return }
		if Gestalt.isOnSimulator { throw Recorder.RecorderError.notImplementedOnSimulator }
		
		if await !requestPermission() { throw Recorder.RecorderError.noPermissions }
		inputNode = audioEngine.inputNode
		
		self.fullTranscript = ""
		self.currentTranscription = SpeechTranscription()
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
		isRunning = true
		objectWillChange.send()
	}
	
	@MainActor public func stop() {
		currentTranscription.finalize()
		
		if isRunning {
			audioEngine.stop()
			isRunning = false
		}
		
		inputNode?.removeTap(onBus: 0)
		recognitionRequest?.endAudio()
		
		recognitionRequest = nil
		inputNode = nil
		recognitionTask?.cancel()
		recognitionTask = nil
		objectWillChange.send()
	}

}
