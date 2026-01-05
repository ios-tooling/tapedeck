//
//  Transcriptionist.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

#if os(iOS)
import Suite
import AVFoundation
import Speech

@MainActor public class SpeechTranscriptionist: NSObject, ObservableObject {
	public static let instance = SpeechTranscriptionist()
	
	let audioEngine = AVAudioEngine()
	var inputNode: AVAudioNode?
	let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!

	// Legacy API properties (iOS 15-18)
	var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	var recognitionTask: SFSpeechRecognitionTask?

	// iOS 26+ properties
	@available(iOS 26.0, *)
	var speechAnalyzer: SpeechAnalyzer? {
		get { _speechAnalyzer as? SpeechAnalyzer }
		set { _speechAnalyzer = newValue }
	}
	fileprivate var _speechAnalyzer: Any?

	@available(iOS 26.0, *)
	var inputContinuation: AsyncStream<AnalyzerInput>.Continuation? {
		get { _inputContinuation as? AsyncStream<AnalyzerInput>.Continuation }
		set { _inputContinuation = newValue }
	}
	fileprivate var _inputContinuation: Any?

	var analysisTask: Task<Void, Never>?

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
		addAsObserver(of: UIApplication.didBecomeActiveNotification, selector: #selector(didBecomeActive))
	}
	
	public func clearTranscript() {
		currentTranscription = SpeechTranscription()
	}
	
	@objc func didBecomeActive() {
		objectWillChange.send()
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
			stop()
		}
	}
	
	public var isAvailable: Bool {
		!AVAudioSession.sharedInstance().isOtherAudioPlaying
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
	nonisolated public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
		print("Detected speech")
	}
	
	nonisolated public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
		print("speechRecognitionTaskFinishedReadingAudio")
	}
	
	nonisolated public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
		print("speechRecognitionTaskWasCancelled")
	}
	

	nonisolated public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition result: SFSpeechRecognitionResult) {
		print("Done Recognizing: \(result.bestTranscription.formattedString)")
	}
	
	nonisolated public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
		print("Done recognizing successfully: \(successfully)")
	}
}

extension SpeechTranscriptionist: SFSpeechRecognizerDelegate {
	nonisolated public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
	}
}
#endif
