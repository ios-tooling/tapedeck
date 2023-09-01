//
//  File.swift
//
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation
import AVFoundation
import Speech

extension Microphone {
	@discardableResult public func startRecognizing(textCallback: @escaping (String) -> Void) throws -> Bool {
		if speech == nil { speech = Speech() }
		
		guard let speech else { return false }
		
		if speech.isRunning {
			speech.textCallback = textCallback
		} else {
			try speech.start(textCallback: textCallback)
		}
		
		return speech.isRunning
	}
	
	public func stopRecognizing() {
		speech?.stop()
	}

	class Speech: NSObject {
		private let audioEngine = AVAudioEngine()
		private var inputNode: AVAudioNode?
		private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
		
		private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
		private var recognitionTask: SFSpeechRecognitionTask?
		var textCallback: ((String) -> Void)?

		var isRunning = false
		
		override init() {
			super.init()
			speechRecognizer.delegate = self
		}
		
		func start(textCallback: ((String) -> Void)?) throws {
			inputNode = audioEngine.inputNode
			
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
		
		func stop() {
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
					print("Recognized: \(result.bestTranscription.formattedString)")
					isFinal = result.isFinal
				}
				
				if error != nil || isFinal {
					self.stop()
				}
			}
		}
	}
}

extension Microphone.Speech: SFSpeechRecognizerDelegate {
	func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
		print("Speech recognizer availability changed to \(available)")
	}
}
