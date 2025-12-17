//
//  AVAudioSessionWrapper.swift
//
//
//  Created by Ben Gottlieb on 9/10/23.
//

#if os(iOS)
import Suite
import AVFoundation

public class AVAudioSessionWrapper {
	public static let instance = AVAudioSessionWrapper()
	
	let session = AVAudioSession.sharedInstance()
	var activeCount = 0
	
	public var defaultToSpeaker = true
	
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

	public func start() throws {
		if activeCount > 0 {
			activeCount += 1
		}
		
		var options: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .allowBluetoothHFP, .overrideMutedMicrophoneInterruption, .mixWithOthers]
		
		if defaultToSpeaker { options.insert(.defaultToSpeaker) }
		try session.setCategory(.playAndRecord, options: options)
		try session.setActive(true)
		activeCount = 1
	}
	
	public func stop() throws {
		if activeCount == 1 {
			try session.setActive(false)
		}
		
		activeCount -= 1
	}
}
#endif
