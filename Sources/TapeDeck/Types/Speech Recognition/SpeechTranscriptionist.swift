//
//  Transcriptionist.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Suite
import AVFoundation
import Speech

public class SpeechTranscriptionist: NSObject, ObservableObject {
	public static let instance = SpeechTranscriptionist()
	
	let audioEngine = AVAudioEngine()
	var inputNode: AVAudioNode?
	let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
	
	var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	var recognitionTask: SFSpeechRecognitionTask?
	var textCallback: ((TranscriptionResult) -> Void)?
	var observationToken: Any?
	
	public enum TranscriptionResult { case phrase(String, Double), pause }
	
	@Published public var currentTranscription = SpeechTranscription()

	public var isRunning = false
	var lastString = ""
	var fullTranscript = ""
	var pauseTask: Task<Void, Never>?
	var pauseDuration = 3.0
	
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
	
	public func setRunning(_ running: Bool) async throws {
		if running == isRunning { return }
		
		if running {
			try await start()
		} else {
			await stop()
		}
	}
	
	
	func buildRecognitionTask() -> SFSpeechRecognitionTask? {
		guard let recognitionRequest else { return nil }
		
//		let task = speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
		let task = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
			if let error {
				let ns = error as NSError
				if ns.domain == "kAFAssistantErrorDomain", ns.code == 1110 { return }
				print("Recognition Error: \(error)")
				return
			}
			
			self.currentTranscription.replaceRecentText(with: result)
			
			if let best = result?.bestTranscription {
				let confidence = best.segments.map { Double($0.confidence) }.average() ?? 0.0

				if best.formattedString.hasPrefix(self.lastString) {
					self.fullTranscript += best.formattedString.dropFirst(self.lastString.count) + " "
				}
				self.lastString = best.formattedString
				self.textCallback?(.phrase(self.lastString, confidence))
				if confidence == 0 {
					if #available(iOS 16.0, *) {
						self.pauseTask?.cancel()
						self.pauseTask = Task {
							do {
								try await Task.sleep(for: .seconds(self.pauseDuration))
								self.textCallback?(.pause)
							} catch { }
						}
					}
				}
			}
		}

		return task
	}
}


extension SpeechTranscriptionist: SFSpeechRecognitionTaskDelegate {
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

extension SpeechTranscriptionist: SFSpeechRecognizerDelegate {
	public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
	}
}
