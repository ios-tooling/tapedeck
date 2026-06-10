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
	
	public func start() throws {
		if activeCount > 0 {
			activeCount += 1
			return
		}

		var options: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .allowBluetoothHFP, .overrideMutedMicrophoneInterruption, .mixWithOthers]

		if defaultToSpeaker { options.insert(.defaultToSpeaker) }
		try session.setCategory(.playAndRecord, options: options)
		try session.setActive(true)
		activeCount = 1
	}
	
	public func stop() throws {
		guard activeCount > 0 else { return }

		activeCount -= 1

		if activeCount == 0 {
			try session.setActive(false)
		}
	}
}
#endif
