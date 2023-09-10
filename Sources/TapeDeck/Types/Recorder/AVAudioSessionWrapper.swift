//
//  File.swift
//
//
//  Created by Ben Gottlieb on 9/10/23.
//

import Suite
import AVFoundation

class AVAudioSessionWrapper {
	static let instance = AVAudioSessionWrapper()
	
	let session = AVAudioSession.sharedInstance()
	var activeCount = 0
	
	public var hasRecordingPermissions = CurrentValueSubject<Bool, Never>(AVAudioSession.sharedInstance().recordPermission == .granted)

	public func requestRecordingPermissions() async -> Bool {
		if hasRecordingPermissions.value { return true }
		if Gestalt.isOnSimulator { return false }

		return await withCheckedContinuation { continuation in
			session.requestRecordPermission { granted in
				self.hasRecordingPermissions.send(granted)
				continuation.resume(returning: granted)
			}
		}
	}

	func start() throws {
		if activeCount > 0 {
			activeCount += 1
		}
		try session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker, .duckOthers])
		try session.setActive(true)
		activeCount = 1
	}
	
	func stop() throws {
		if activeCount == 1 {
			try session.setActive(false)
		}
		
		activeCount -= 1
	}
}
