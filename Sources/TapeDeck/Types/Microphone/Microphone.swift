//
//  Microphone.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Combine
import Suite

@MainActor public class Microphone: NSObject, ObservableObject, MicrophoneListener {
	static public let instance = Microphone()
	
	public enum State { case idle, recording, paused }
	private var activeListener: MicrophoneListener?
	private var listenerStack: [MicrophoneListener] = []
	private weak var pollingTimer: Timer?
	private var isPausedDueToInterruption = false
	private var interruptCount = 0
	var speech: Speech?

	public var pollingInterval: Frequency = 10 { didSet { self.setupTimer() }}
	@Published public private(set) var isListening = false

	public struct Notifications {
		public static let volumeChanged = Notification.Name("Microphone.Notifications.VolumeChanged")
	}
	
	public let history = History()
	let recordingSession = AVAudioSession.sharedInstance()
	let audioRecorder = try! AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: AudioSettings.m4a.settings)
	private var cancelBag: Set<AnyCancellable> = []

	override init() {
		super.init()
		
		AVAudioSession.interruptionNotification.publisher()
			.receive(on: RunLoop.main)
			.sink { note in
				self.handleInterruption(note: note)
			}.store(in: &cancelBag)
	}

	func handleInterruption(note: Notification) {
		if let type = note.interruptionType {
			switch type {
			case .began:
				logg("Recording Interrruption began")
				Task {
					try? await self.stop()
					isPausedDueToInterruption = true
					interruptCount += 1
				}
                
			case .ended:
                if self.interruptCount == 0 { return }
                
                DispatchQueue.main.async(after: 1.0) {
						  logg("Recording Interrruption ended \(self.interruptCount)")
                    self.interruptCount -= 1
                    if self.interruptCount != 0 || !self.isPausedDueToInterruption { return }
						  Task { try? await self.start() }
                }
				
			@unknown default:
				logg("Recording Unknown interruption kind")
			}
		}
	}
	
	public var state: State {
		if self.isPausedDueToInterruption { return .paused }
		if !self.isListening { return .idle }
		return .recording
	}
	
	public func toggle() async throws {
		if self.isListening {
			try await activeListener?.stop()
		} else {
			try await self.start()
		}
	}
	
	func setActive(_ listener: MicrophoneListener) async throws {
		if activeListener === listener { return }
		
		if let active = activeListener {
			try await active.stop()
			listenerStack.append(active)
		}
		activeListener = listener
	}
	
	func clearActive(_ listener: MicrophoneListener) {
		if activeListener !== listener { return }
		
		if let last = listenerStack.last {
			listenerStack.removeLast()
			activeListener = last
			DispatchQueue.main.async {
				Task { _ = try? await last.start() }
			}
		} else {
			activeListener = nil
		}
	}

	public var hasRecordingPermissions = CurrentValueSubject<Bool, Never>(AVAudioSession.sharedInstance().recordPermission == .granted)
	public func requestRecordingPermissions() async -> Bool {
		await withCheckedContinuation { continuation in
			recordingSession.requestRecordPermission { granted in
				self.hasRecordingPermissions.send(granted)
				continuation.resume(returning: granted)
			}
		}
	}

	@discardableResult
	public func start() async throws -> Bool {
		isPausedDueToInterruption = false
		if isListening {
			try await setActive(self)
			return true
		}
		
		if !hasRecordingPermissions.value {
			if await !requestRecordingPermissions() { return false }
			
		}

		//self.history.reset()
		
		do {
			setupSession()
			try self.recordingSession.setCategory(.playAndRecord, options: [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker, .duckOthers])
			try self.recordingSession.setActive(true)
		} catch {
			logg("Error when starting the recorder: \((error as NSError).code.characterCode) \(error.localizedDescription)")
			return false
		}
		
		audioRecorder.prepareToRecord()
		audioRecorder.delegate = self
		audioRecorder.isMeteringEnabled = true
		
		self.setupTimer()
		if audioRecorder.record() {
			isListening = true
			setupTimer()
			try await setActive(self)
			objectWillChange.sendOnMain()
			return true
		}
		
		return false
	}
	
	func setupSession() {
		let audioSession = AVAudioSession.sharedInstance()
		try? audioSession.setCategory(.playAndRecord, options: [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker, .duckOthers])
		try? audioSession.setActive(true)
	}
	
	var startedAt: TimeInterval = 0
	
	func setupTimer() {
		if !isListening { return }
		pollingTimer?.invalidate()
		pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval.timeInterval, repeats: true) { _ in
			Task { @MainActor in self.updateLevels() }
		}

	}
	
	public func stop() async throws {
		clearActive(self)
		if !isListening { return }
		pollingTimer?.invalidate()
		audioRecorder.pause()
		isListening = false
		isPausedDueToInterruption = false
		objectWillChange.sendOnMain()
	}
	
	func updateLevels() {
		guard isListening, audioRecorder.isRecording else { return }
		audioRecorder.updateMeters()
		
		let avgFullScale = audioRecorder.averagePower(forChannel: 0)
		let environmentDBAvgSPL = Volume(detectedRoomVolume: Double(avgFullScale)) ?? .silence
		
		self.history.record(volume: environmentDBAvgSPL)
	}
	
	
}

extension Microphone: AVAudioRecorderDelegate {
	public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
		logg(error: error, "Recording error")
	}
	
	public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
	}
}


