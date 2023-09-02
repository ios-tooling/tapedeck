//
//  Transcriptionist.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation
import AVFoundation
import Speech

public class Transcriptionist: NSObject, ObservableObject {
	public static let instance = Transcriptionist()
	
	private let audioEngine = AVAudioEngine()
	private var inputNode: AVAudioNode?
	private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
	
	private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	private var recognitionTask: SFSpeechRecognitionTask?
	var textCallback: ((String) -> Void)?
	var observationToken: Any?
	
	@Published public var currentTranscription = Transcription()

	var isRunning = false

	override init() {
		super.init()
		speechRecognizer.delegate = self
	}
	
	public func requestPermission() async -> Bool {
		if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
		
		return await withCheckedContinuation { continuation in
			SFSpeechRecognizer.requestAuthorization { status in
				continuation.resume(returning: status == .authorized)
			}
		}
	}
	
	public func start(textCallback: ((String) -> Void)?) async throws {
		if isRunning { return }
		
		if await !requestPermission() { return }
		inputNode = audioEngine.inputNode
		
		self.fullTranscript = ""
		self.currentTranscription = Transcription()
		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
		guard let recognitionRequest = recognitionRequest else { throw Recorder.RecorderError.unableToCreateRecognitionRequest }
	//	recognitionRequest.shouldReportPartialResults = true
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
	}
	
	public func stop() {
		print(self.fullTranscript)
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
	}
	
	var lastString = ""
	var fullTranscript = ""
	
	func buildRecognitionTask() -> SFSpeechRecognitionTask? {
		guard let recognitionRequest else { return nil }
		
//		let task = speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
		let task = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
			if let error {
				print("Recognition Error: \(error)")
				return
			}
			
			if let best = result?.bestTranscription {
				if best.formattedString.hasPrefix(self.lastString) {
					self.fullTranscript += best.formattedString.dropFirst(self.lastString.count) + " "
				}
				self.lastString = best.formattedString
			}
		}

		return task
//		{ result, error in
//			var isFinal = false
//			
//			if let result {
//				self.textCallback?(result.bestTranscription.formattedString)
//				// Update the text view with the results.
//				//self.textView.text = result.bestTranscription.formattedString
//				//print(result)
//				print("Recognized: \(result.bestTranscription.formattedString)")
//				isFinal = result.isFinal
//			}
//			
//			if error != nil || isFinal {
//				self.stop()
//			}
//		}
	}
}


extension Transcriptionist: SFSpeechRecognitionTaskDelegate {
	public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
		print("Detected speech")
	}
	
	public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
		print("speechRecognitionTaskFinishedReadingAudio")
	}
	
	public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
		print("speechRecognitionTaskWasCancelled")
	}
	

	public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
		print("Done Recognizing: \(result.bestTranscription.formattedString)")
	}
	
	public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
		print("Done recognizing successfully: \(successfully)")
	}
}

extension Transcriptionist: SFSpeechRecognizerDelegate {
	public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
		print("Speech recognizer availability changed to \(available)")
	}
}
