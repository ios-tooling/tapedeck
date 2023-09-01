//
//  File.swift
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
	
	@Published public var currentTranscription = Transcription()

	var isRunning = false

	override init() {
		super.init()
		speechRecognizer.delegate = self
	}
	
	public func start(textCallback: ((String) -> Void)?) throws {
		if isRunning { return }
		inputNode = audioEngine.inputNode
		
		self.currentTranscription = Transcription()
		recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
		guard let recognitionRequest = recognitionRequest else { throw Recorder.RecorderError.unableToCreateRecognitionRequest }
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
	}
	
	public func stop() {
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
	
	func buildRecognitionTask() -> SFSpeechRecognitionTask? {
		guard let recognitionRequest else { return nil }
		
		return speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
			var isFinal = false
			
			if let result {
				self.textCallback?(result.bestTranscription.formattedString)
				// Update the text view with the results.
				//self.textView.text = result.bestTranscription.formattedString
				//print(result)
				print("Recognized: \(result.bestTranscription.formattedString)")
				isFinal = result.isFinal
			}
			
			if error != nil || isFinal {
				self.stop()
			}
		}
	}
}

extension Transcriptionist: SFSpeechRecognizerDelegate {
	public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
		print("Speech recognizer availability changed to \(available)")
	}
}
