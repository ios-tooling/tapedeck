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
import OSLog

@MainActor public class Microphone: NSObject, ObservableObject, MicrophoneListener {
	static public let instance = Microphone()
	
	public enum State { case idle, recording, paused }
	private var activeListener: MicrophoneListener?
	private var listenerStack: [MicrophoneListener] = []
	private weak var pollingTimer: Timer?
	private var isPausedDueToInterruption = false
	private var interruptCount = 0

	public var pollingInterval: Frequency = 10 { didSet { self.setupTimer() }}
	@Published public private(set) var isListening = false

	public struct Notifications {
		public static let volumeChanged = Notification.Name("Microphone.Notifications.VolumeChanged")
	}
	
	public let history = History()
	let audioRecorder = try! AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: AudioSettings.m4a.settings)
	private var cancelBag: Set<AnyCancellable> = []

	override init() {
		super.init()
		
		AVAudioSession.interruptionNotification.publisher()
			.receive(on: RunLoop.main)
			.sink { note in
				//self.handleInterruption(note: note)
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
                
                Task { @MainActor in
						 try? await Task.sleep(nanoseconds: 1_000_000_000)
						 os_log("Recording Interrruption ended \(self.interruptCount)")
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
		
		if let active = activeListener, active !== self {
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
			Task { @MainActor in _ = try? await last.start() }
		} else {
			activeListener = nil
		}
		
		if activeListener == nil { isListening = false }
	}

	@discardableResult
	public func start() async throws -> Bool { try await start(resettingHistory: false) }

	@discardableResult
	public func start(resettingHistory: Bool) async throws -> Bool {
		isPausedDueToInterruption = false
		if isListening {
			try await setActive(self)
			if resettingHistory { history.reset() }
			return true
		}
		
		if await !AVAudioSessionWrapper.instance.requestRecordingPermissions() { return false }

		//self.history.reset()
		
		do {
			try AVAudioSessionWrapper.instance.start()
		} catch {
			logg("Error when starting the recorder: \((error as NSError).code.characterCode) \(error.localizedDescription)")
			return false
		}
		
		audioRecorder.prepareToRecord()
		audioRecorder.delegate = self
		audioRecorder.isMeteringEnabled = true
		
		if audioRecorder.record() {
			isListening = true
			setupTimer()
			try await setActive(self)
			objectWillChange.sendOnMain()
			return true
		}
		
		return false
	}
	
	var startedAt: TimeInterval = 0
	
	func setupTimer() {
		if !isListening { return }
		pollingTimer?.invalidate()
		pollingTimer = Timer.nonPausingTimer(withTimeInterval: pollingInterval.timeInterval) { _ in
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
		guard isListening else { return }
		audioRecorder.updateMeters()
		
		let avgFullScale = audioRecorder.averagePower(forChannel: 0)
		let environmentDBAvgSPL = Volume(detectedRoomVolume: Double(avgFullScale)) ?? .silence
	
		self.history.record(volume: environmentDBAvgSPL)
		objectWillChange.send()
	}
	
	
}

extension Microphone: AVAudioRecorderDelegate {
	nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
		os_log("Recording error: \(error)")
	}
	
	nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
	}
}


